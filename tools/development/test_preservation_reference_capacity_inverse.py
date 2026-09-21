"""Read-only inverse regressions; mutations are in-memory and no EVM is run."""
from pathlib import Path
import unittest

from tools.development import check_preservation_reference_capacity_inverse as check


class PreservationReferenceCapacityInverseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sources, cls.baseline = check.load(Path(__file__).resolve().parents[2])
        check.validate(cls.sources, cls.baseline)  # Negative tests require a valid positive control.

    def reject(self, path, before, after, count=1):
        self.assertEqual(self.sources[path].count(before), count, "mutation must target exact source")
        changed = dict(self.sources)
        changed[path] = changed[path].replace(before, after)
        with self.assertRaises(check.InverseError):
            check.validate(changed, self.baseline)

    def test_working_extractions_reconstruct_both_pinned_hosts(self):
        report = check.validate(self.sources, self.baseline)
        self.assertEqual(report["status"], "PASS_PRESERVATION_REFERENCE_CAPACITY_SOURCE_INVERSE_ONLY")
        self.assertEqual(set(report["files"]), set(check.FILES))

    def test_only_comments_and_whitespace_are_ignored(self):
        changed = {p: "// harmless { function fake() {} }\n" + s.replace("\r\n", "\n")
                   for p, s in self.sources.items()}
        check.validate(changed, self.baseline)

    def test_lexer_preserves_literals_and_multichar_operators(self):
        self.assertNotEqual(check.lex('x = "a b";'), check.lex('x = "ab";'))
        self.assertNotEqual(check.lex("x<=y;"), check.lex("x< =y;"))
        self.assertEqual(check.lex('x="/*text*/"; // ignored'), ('x', '=', '"/*text*/"', ';'))

    def test_snapshot_wrapper_requires_caller_memory_normalization(self):
        self.reject(check.REFERENCE, "original.expectedSourceHash = 0;", "")

    def test_snapshot_normalization_must_follow_linked_call(self):
        call = "f = SnapshotPayloadReads.snapshot(d, source, original, receipt, family);"
        normalization = "original.expectedSourceHash = 0;"
        self.assertEqual(self.sources[check.REFERENCE].count(call), 1)
        self.assertEqual(self.sources[check.REFERENCE].count(normalization), 1)
        changed = dict(self.sources)
        changed[check.REFERENCE] = changed[check.REFERENCE].replace(call, "__CALL__").replace(
            normalization, call).replace("__CALL__", normalization)
        with self.assertRaises(check.InverseError):
            check.validate(changed, self.baseline)

    def test_snapshot_receipt_copy_cannot_disappear(self):
        self.reject(check.SNAPSHOT, "receipt = abi.decode(abi.encode(receipt), (S.Receipt));", "")

    def test_snapshot_family_domain_cannot_change(self):
        self.reject(check.SNAPSHOT, "6529STREAM_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V2",
                    "6529STREAM_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V1")

    def test_snapshot_read_bound_and_error_cannot_change(self):
        self.reject(check.SNAPSHOT, "receipt.manifestBytes + 96", "receipt.manifestBytes + 128")
        self.reject(check.SNAPSHOT, "revert T.PolicyReferenceDependency(target);",
                    "revert T.InvalidPolicyReference();")

    def test_snapshot_worker_must_remain_public(self):
        self.reject(check.SNAPSHOT, ") public view returns (S.Source memory f)",
                    ") private view returns (S.Source memory f)")

    def test_token_host_original_tuple_is_exact(self):
        self.reject(check.TOKENS, "bytes entropy;", "bytes32 entropy;")

    def test_token_wrapper_arguments_are_exact(self):
        self.reject(check.TOKENS, "return OriginalReads.original(d, c, sd, index, token);",
                    "return OriginalReads.original(d, c, sd, token, index);")

    def test_entropy_hash_keeps_dynamic_bytes(self):
        self.reject(check.ORIGINAL, "                        o.entropy,",
                    "                        o.output.entropy,")

    def test_token_original_read_order_is_exact(self):
        decode = "o.selection = abi.decode(raw, (Selection.TokenSelection));"
        canonical = "IO.canonical(sd.targets[6], raw, abi.encode(o.selection));"
        self.assertEqual(self.sources[check.ORIGINAL].count(decode), 1)
        self.assertEqual(self.sources[check.ORIGINAL].count(canonical), 1)
        changed = dict(self.sources)
        changed[check.ORIGINAL] = changed[check.ORIGINAL].replace(decode, "__DECODE__").replace(
            canonical, decode).replace("__DECODE__", canonical)
        with self.assertRaises(check.InverseError):
            check.validate(changed, self.baseline)

    def test_token_source_bound_and_preservation_guard_are_exact(self):
        self.reject(check.ORIGINAL, "24000,", "24001,")
        self.reject(check.ORIGINAL, "Binding.requireCurrent(o.output.preservation, o.selection, d.readGas);", "")

    def test_host_type_qualification_cannot_redirect(self):
        self.reject(check.ORIGINAL, "Tokens.Original", "Other.Original", count=2)

    def test_unaccounted_helpers_or_imports_reject(self):
        self.reject(check.SNAPSHOT, "library StreamPreservationPolicyReferenceSnapshotPayloadReadsV1 {",
                    "library StreamPreservationPolicyReferenceSnapshotPayloadReadsV1 { function extra() public pure {}")
        self.reject(check.ORIGINAL, './StreamPreservationPolicyRenderCriticalTokenReadsV1.sol',
                    './AnotherTokenReads.sol')
        self.reject(check.REFERENCE, './StreamPreservationPolicyReferenceSnapshotPayloadReadsV1.sol',
                    './UntrustedSnapshot.sol')

    def test_exact_five_propagated_error_declarations_are_enforced(self):
        for declaration in check.PROPAGATED_ERRORS:
            with self.subTest(declaration=declaration):
                self.reject(check.TOKENS, declaration, "")
        self.reject(check.TOKENS, "error PreservationReadFailed(address target, bytes4 selector);",
                    "error PreservationReadFailed(address target, bytes32 selector);")
        self.reject(check.TOKENS, "error InvalidPreservationBinding();",
                    "error InvalidPreservationBinding(); error ExtraError();")

    def test_read_facts_keeps_exact_return_tuple_and_host_arguments(self):
        self.reject(check.SNAPSHOT, "uint64 revision,", "uint256 revision,")
        self.reject(check.REFERENCE, "p.observation.snapshotRevision,", "uint64(0),")
        self.reject(check.REFERENCE, ") != f.contentRootRecordHash", ") != f.snapshot.recordHash")

    def test_read_facts_preserves_current_record_canonical_and_receipt_checks(self):
        self.reject(check.SNAPSHOT, "SnapRead.requireCurrent(", "SnapRead.original(")
        self.reject(check.SNAPSHOT, "_canonical(d.targets[5], raw, abi.encode(original, receipt));", "")
        self.reject(check.SNAPSHOT, "abi.encode(currentSnapshot.receipt)", "abi.encode(receipt)")
        self.reject(check.SNAPSHOT, "4096,", "8192,")

    def test_read_facts_retains_current_before_record_external_read(self):
        source = self.sources[check.SNAPSHOT]
        first_start = source.index("SnapRead.Evidence memory currentSnapshot")
        first_end = source.index(");", first_start) + 2
        second_start = source.index("bytes memory raw = Reads.dynamicRead(", first_end)
        second_end = source.index(");", second_start) + 2
        first, second = source[first_start:first_end], source[second_start:second_end]
        changed = dict(self.sources)
        changed[check.SNAPSHOT] = source.replace(first, "__CURRENT__").replace(second, first).replace(
            "__CURRENT__", second)
        with self.assertRaises(check.InverseError):
            check.validate(changed, self.baseline)

    def test_read_facts_internal_snapshot_call_is_exact(self):
        self.reject(check.SNAPSHOT, "sourceFacts = snapshot(d, source, original, receipt, family);",
                    "sourceFacts = SnapshotPayloadReads.snapshot(d, source, original, receipt, family);")
        self.reject(check.SNAPSHOT, "contentRootRecord = original.contentRootRecord;",
                    "contentRootRecord = receipt.recordHash;")

    def test_dependency_forwarders_cannot_change_arguments_or_import(self):
        self.reject(check.REFERENCE, "return DependencyReads.bindings(d, family);",
                    "return DependencyReads.bindings(d, Profiles.ORIGINAL_PROFILE);")
        self.reject(check.REFERENCE, "DependencyReads.requireRuntime(d, e);", "")
        self.reject(check.REFERENCE, './StreamPreservationPolicyReferenceDependencyReadsV1.sol',
                    './DifferentDependencies.sol')

    def test_dependency_authentication_and_runtime_tuple_remain_exact(self):
        self.reject(check.DEPENDENCIES, "F.isV2(family);", "")
        self.reject(check.DEPENDENCIES, "i < 7;", "i < 6;")
        self.reject(check.DEPENDENCIES, "source.codeHashes[i] != d.codeHashes[i]", "false")
        self.reject(check.DEPENDENCIES, "o.canonicalizationId != keccak256(\"RAW_BYTES\")", "false")
        self.reject(check.DEPENDENCIES, ") public view {", ") private view {")

    def test_dependency_helper_roster_and_canonical_guard_remain_exact(self):
        self.reject(check.DEPENDENCIES, "library StreamPreservationPolicyReferenceDependencyReadsV1 {",
                    "library StreamPreservationPolicyReferenceDependencyReadsV1 { uint256 extra;")
        self.reject(check.DEPENDENCIES, "revert T.PolicyReferenceDependency(target);",
                    "revert T.InvalidPolicyReference();")

    def test_reference_error_abi_declarations_are_exact(self):
        for declaration in check.REFERENCE_PROPAGATED_ERRORS:
            with self.subTest(declaration=declaration):
                self.reject(check.REFERENCE, declaration, "")
        self.reject(check.REFERENCE, "error PolicyReferenceDependency(address target);",
                    "error PolicyReferenceDependency(bytes32 target);")

    def test_untouched_host_logic_cannot_change(self):
        self.reject(check.TOKENS, "16384,", "16385,")
        self.reject(check.REFERENCE, "count > type(uint64).max", "count >= type(uint64).max")


if __name__ == "__main__":
    unittest.main()
