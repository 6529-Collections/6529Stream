"""Adversarial source-fidelity regressions; never compile or execute Solidity."""
from pathlib import Path
import unittest

from tools.development import check_preservation_record_capacity as check


class PreservationRecordCapacityTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sources, cls.baseline = check.load(Path(__file__).resolve().parents[2])

    def reject(self, path, before, after, *, count=1):
        sources = {key: value.replace("\r\n", "\n") for key, value in self.sources.items()}
        self.assertEqual(sources[path].count(before), count, "mutation must hit its exact intended source")
        sources[path] = sources[path].replace(before, after)
        with self.assertRaises(check.InverseError):
            check.validate(sources, self.baseline)

    def test_frozen_source_inverse(self):
        report = check.validate(self.sources, self.baseline)
        self.assertEqual(report["status"], "PASS_PRESERVATION_RECORD_CAPACITY_SOURCE_INVERSE_ONLY")
        self.assertEqual(report["originalFunctionCount"], 10)
        self.assertEqual(report["helperFunctionRoster"], ["requireCurrent", "recordBytes", "source", "publication"])

    def test_exact_baseline_blob_required_even_for_comment_change(self):
        baseline = dict(self.baseline)
        baseline[check.RECORDS] += "\n// not the authenticated Git blob\n"
        with self.assertRaisesRegex(check.InverseError, "pinned baseline blob differs"):
            check.validate(self.sources, baseline)

    def test_comments_and_line_endings_do_not_change_token_proof(self):
        sources = {path: "// { function fake() }\n" + text.replace("\r\n", "\n").replace("\n", "\r\n")
                   for path, text in self.sources.items()}
        check.validate(sources, self.baseline)

    def test_literals_and_compound_operators_are_not_normalized(self):
        self.assertNotEqual(check.lex('keccak256("RAW_BYTES")'), check.lex('keccak256("RAW_ BYTES")'))
        self.assertNotEqual(check.lex("a<=b"), check.lex("a < = b"))
        self.assertEqual(check.lex('"}/*x*/"'), ('"}/*x*/"',))

    def test_definition_validation_cannot_move_after_source_reads(self):
        self.reject(check.RECORDS,
                    "definitions(d, family);\n        RecordReads.requireCurrent(original, payload, receipt, d, family);",
                    "RecordReads.requireCurrent(original, payload, receipt, d, family);\n        definitions(d, family);")

    def test_helper_payload_integrity_cannot_move_before_source_hash(self):
        self.reject(check.READS,
                    "Sources.sourceHash(d, f, family) != receipt.observation.sourcesHash\n                || Bytes.requireIntact(payload) != receipt.observation.payloadHash",
                    "Bytes.requireIntact(payload) != receipt.observation.payloadHash\n                || Sources.sourceHash(d, f, family) != receipt.observation.sourcesHash")

    def test_prepare_caller_memory_mutations_remain_in_original(self):
        for line in ("p.observation.expectedSourcesHash = 0;", "receipt.observation.sourcesHash = hash;",
                     "receipt.observation.recordHash = 0;", "receipt.observation.recordChainHash = 0;",
                     "receipt.observation.payloadHash = 0;", "receipt.observation.payloadBytes = 0;",
                     "receipt.observation.recordedAt = 0;"):
            with self.subTest(line=line):
                self.reject(check.RECORDS, line, "")

    def test_prepare_normalization_order_is_fixed(self):
        self.reject(check.RECORDS,
                    "p.observation.expectedSourcesHash = 0;\n        receipt.observation.recordHash = 0;",
                    "receipt.observation.recordHash = 0;\n        p.observation.expectedSourcesHash = 0;")

    def test_definitions_and_original_profile_overloads_are_unchanged(self):
        self.reject(check.RECORDS, "known.readGas = d.readGas;", "known.readGas = 1;")
        self.reject(check.RECORDS, "return source(payload, Profiles.ORIGINAL_PROFILE);",
                    "return source(payload, bytes32(0));")

    def test_unknown_helper_member_or_overload_is_rejected(self):
        for member in ("function hidden() public pure {}", "uint256 constant hidden = 7;",
                       "function source(bytes memory raw) public pure returns(bytes memory) { return raw; }"):
            with self.subTest(member=member):
                self.reject(check.READS, "library StreamPreservationPolicyReferenceRecordReadsV1 {",
                            "library StreamPreservationPolicyReferenceRecordReadsV1 {\n    " + member)

    def test_helper_function_roster_includes_copied_publication(self):
        self.reject(check.READS, "function publication(Bytes.Manifest storage original)",
                    "function otherPublication(Bytes.Manifest storage original)")

    def test_decode_tuple_and_canonical_preimage_are_exact(self):
        for before, after in (
            ("raw, (bytes32, uint256, address, T.Publication, T.Receipt, T.SourceFacts, bytes)",
             "raw, (bytes32, uint256, address, T.Publication, T.SourceFacts, T.Receipt, bytes)"),
            ("abi.encode(domain, chain, host, p, r, f, environment)",
             "abi.encode(domain, chain, host, p, r, environment, f)"),
            ("abi.encode(domain, chain, host, p, r, f, environment)",
             "abi.encodePacked(domain, chain, host, p, r, f, environment)"),
            ("F.payloadDomain(family, false)", "F.payloadDomain(family, true)"),
        ):
            with self.subTest(after=after):
                self.reject(check.READS, before, after)

    def test_wrapper_arguments_and_return_paths_are_exact(self):
        for before, after in (
            ("RecordReads.requireCurrent(original, payload, receipt, d, family)",
             "RecordReads.requireCurrent(payload, original, receipt, d, family)"),
            ("return RecordReads.recordBytes(original, receipt);", "return RecordReads.recordBytes(payload, receipt);"),
            ("return RecordReads.source(payload, family);", "return RecordReads.source(payload, bytes32(0));"),
        ):
            with self.subTest(after=after):
                self.reject(check.RECORDS, before, after)

    def test_publication_normalization_guard_remains_in_both_copies(self):
        guard = "if (keccak256(raw) != keccak256(abi.encode(p))) revert T.InvalidPolicyReference();"
        for path in (check.RECORDS, check.READS):
            with self.subTest(path=path):
                self.reject(path, guard, "")
                self.reject(path, "p = abi.decode(raw, (T.Publication));", "p = abi.decode(raw, (T.Publication)); p.observation.expectedSourcesHash = 0;")

    def test_preparation_worker_body_and_private_definitions_are_literal(self):
        for before, after in (
            ("definitions(d, family);", ""),
            ("receipt.observation.sourcesHash = hash;", "receipt.observation.sourcesHash = bytes32(0);"),
            ("p.observation.expectedSourcesHash = 0;", ""),
            ("environment.length != p.observation.environment.manifestBytes", "environment.length == 0"),
            ("F.payloadDomain(family, false), d.chainId, address(this), p, receipt, f, environment",
             "F.payloadDomain(family, false), d.chainId, msg.sender, p, receipt, f, environment"),
            ("canonical.length > 524288", "canonical.length > 1048576"),
            ("known.readGas = d.readGas;", "known.readGas = 1;"),
            ("bytes32 family) private view", "bytes32 family) public view"),
        ):
            with self.subTest(after=after):
                self.reject(check.PREPARATION, before, after)

    def test_preparation_read_order_cannot_relocate(self):
        self.reject(check.PREPARATION,
                    "definitions(d, family);\n        T.SourceFacts memory f = Sources.requireSource(d, p, current, family);",
                    "T.SourceFacts memory f = Sources.requireSource(d, p, current, family);\n        definitions(d, family);")

    def test_preparation_wrapper_arguments_and_memory_restoration_are_exact(self):
        self.reject(check.RECORDS,
                    "Preparation.prepare(inventories, d, p, receipt, current, family)",
                    "Preparation.prepare(inventories, d, p, receipt, false, family)")
        self.reject(check.RECORDS,
                    "(hash, canonical) = Preparation.prepare(inventories, d, p, receipt, current, family);\n        receipt.observation.sourcesHash = hash;",
                    "receipt.observation.sourcesHash = hash;\n        (hash, canonical) = Preparation.prepare(inventories, d, p, receipt, current, family);")

    def test_preparation_has_no_unknown_members_or_host_link_cycle(self):
        self.reject(check.PREPARATION, "library StreamPreservationPolicyReferencePreparationV1 {",
                    "library StreamPreservationPolicyReferencePreparationV1 {\n    function hidden() public pure {}")
        self.reject(check.PREPARATION, "definitions(d, family);", "Records.definitions(d, family);")
        self.reject(check.PREPARATION, "pragma solidity ^0.8.19;",
                    'pragma solidity ^0.8.19; import { StreamPreservationPolicyReferenceRecordsV1 as Records } from "./StreamPreservationPolicyReferenceRecordsV1.sol";')

    def test_original_prepare_overload_is_unchanged(self):
        self.reject(check.RECORDS,
                    "return prepare(inventories, d, p, receipt, current, Profiles.ORIGINAL_PROFILE);",
                    "return prepare(inventories, d, p, receipt, current, Profiles.FAMILY_PROFILE);")

    def test_propagated_error_must_exist_exactly_once_with_original_signature(self):
        for replacement in ("", "error InvalidPolicyReference(uint256 reason);",
                            "error InvalidReference();",
                            "error InvalidPolicyReference(); error InvalidPolicyReference();",
                            "error InvalidPolicyReference(); error Unexpected();"):
            with self.subTest(replacement=replacement):
                self.reject(check.RECORDS, "error InvalidPolicyReference();", replacement)

    def test_propagated_error_cannot_hide_in_helper_or_move_after_functions(self):
        for path, name in ((check.READS, "StreamPreservationPolicyReferenceRecordReadsV1"),
                           (check.PREPARATION, "StreamPreservationPolicyReferencePreparationV1")):
            with self.subTest(path=path):
                self.reject(path, "library " + name + " {",
                            "library " + name + " { error InvalidPolicyReference();")
        sources = dict(self.sources)
        current = sources[check.RECORDS].replace("error InvalidPolicyReference();", "")
        at = current.rfind("}")
        sources[check.RECORDS] = current[:at] + "error InvalidPolicyReference();" + current[at:]
        with self.assertRaises(check.InverseError):
            check.validate(sources, self.baseline)

    def test_helper_import_cannot_redirect_fixed_reader(self):
        self.reject(check.READS, 'from "./StreamPreservationPolicyReferenceSourceReadsV1.sol";',
                    'from "./DifferentSourceReads.sol";')

    def test_unknown_host_code_and_trailing_declaration_are_rejected(self):
        self.reject(check.RECORDS, "library StreamPreservationPolicyReferenceRecordsV1 {",
                    "library StreamPreservationPolicyReferenceRecordsV1 {\n    function hidden() public pure {}")
        sources = dict(self.sources)
        sources[check.READS] += "\ncontract Extra {}\n"
        with self.assertRaises(check.InverseError):
            check.validate(sources, self.baseline)


if __name__ == "__main__":
    unittest.main()
