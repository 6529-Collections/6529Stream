// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamEntropyDirectReadEncoding as Encoding
} from "../../../smart-contracts/domains/entropy/StreamEntropyDirectReadEncoding.sol";
import {
    IStreamEntropyPolicyContinuity as C
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol";
import {
    IStreamEntropyCollectionPolicy as P
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    IStreamEntropyRecoveryPolicies as R
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyRecoveryPolicies.sol";

/// @notice Exercises the direct getter return convention after Solidity decodes nested memory.
contract EntropyDirectReadEncodingHarness {
    function policy(C.PolicyExport memory p) external pure returns (C.PolicyExport memory) {
        bytes memory encoded = Encoding.policy(p);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function recovery(C.RecoveryExport memory r) external pure returns (C.RecoveryExport memory) {
        bytes memory encoded = Encoding.recovery(r);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }
}

/// @notice Differential encoding tests only; these deliberately vary every typed field independently.
/// @dev Semantically incompatible policy combinations are valid encoding inputs, not import claims.
contract StreamEntropyDirectReadEncodingTest {
    EntropyDirectReadEncodingHarness private harness;

    function setUp() public {
        harness = new EntropyDirectReadEncodingHarness();
    }

    function testPolicyZeroFields() public view {
        C.PolicyExport memory p;
        _assertPolicy(p);
    }

    function testPolicyEveryValidEnumAndBooleanPattern() public view {
        for (uint8 flags = 0; flags < 32; ++flags) {
            for (uint8 modes = 0; modes < 9; ++modes) {
                C.PolicyExport memory p = _policy(bytes32(uint256(73)), 0, 0, flags, modes);
                p.profile = C.PolicyProfile(flags % 2);
                p.record.securityClass = P.SecurityClass(flags % 2);
                p.policy.securityClass = P.SecurityClass((flags / 2) % 2);
                p.record.renderRequirement = P.RenderRequirement((flags / 4) % 2);
                p.policy.renderRequirement = P.RenderRequirement((flags / 8) % 2);
                _assertPolicy(p);
            }
        }
    }

    function testPolicyMaximumPackedValuesAndFee() public view {
        C.PolicyExport memory p =
            _policy(bytes32(type(uint256).max), type(uint256).max, type(uint256).max, 31, 5);
        p.policy.reveal.requestMode = type(uint8).max;
        p.policyOrigin = address(type(uint160).max);
        p.policy.provider = address(type(uint160).max);
        _assertPolicy(p);
    }

    function testFuzzPolicyAllFields(
        bytes32 seed,
        uint256 counters,
        uint256 fee,
        uint8 flags,
        uint8 modes
    ) public view {
        _assertPolicy(_policy(seed, counters, fee, flags, modes));
    }

    function testRecoveryZeroSteps() public view {
        _assertRecovery(_recovery(bytes32(uint256(41)), 0, 0, 0));
    }

    function testRecoveryOneStepWithMaximumPackedValues() public view {
        C.RecoveryExport memory r = _recovery(bytes32(type(uint256).max), type(uint256).max, 1, 7);
        r.policy.steps[0].provider = address(type(uint160).max);
        r.policy.steps[0].providerEpoch = type(uint32).max;
        r.policy.steps[0].notBeforeBlocks = type(uint64).max;
        r.policyOrigin = address(type(uint160).max);
        r.successor = address(type(uint160).max);
        _assertRecovery(r);
    }

    function testRecoveryThirtyTwoDistinctNestedSteps() public view {
        _assertRecovery(_recovery(keccak256("thirty two distinct steps"), 123456789, 32, 5));
    }

    function testRecoveryReorderedAndAliasedNestedMemory() public view {
        C.RecoveryExport memory r = _recovery(keccak256("nested pointers"), 87654321, 32, 6);
        R.FreshRecoveryStep memory first = r.policy.steps[0];
        r.policy.steps[0] = r.policy.steps[31];
        r.policy.steps[31] = first;
        // Two array entries may reference the same memory struct. Encoding must flatten values.
        r.policy.steps[11] = r.policy.steps[0];
        r.policy.steps[11].notBeforeBlocks = 918273645;
        require(r.policy.steps[0].notBeforeBlocks == 918273645, "shared step memory fixture");
        _assertRecovery(r);
    }

    function testFuzzRecoveryAllMetadataAndNestedSteps(
        bytes32 seed,
        uint256 counters,
        uint8 count,
        uint8 flags
    ) public view {
        _assertRecovery(_recovery(seed, counters, uint256(count) % 33, flags));
    }

    function _assertPolicy(C.PolicyExport memory p) private view {
        bytes memory expected = abi.encode(p);
        bytes32 original = keccak256(expected);
        bytes memory actual = Encoding.policy(p);
        require(expected.length == 1184 && actual.length == 1184, "policy fixed length");
        require(keccak256(actual) == original, "policy canonical bytes");
        require(keccak256(abi.encode(p)) == original, "policy input preserved");
        (bool ok, bytes memory returned) =
            address(harness).staticcall(abi.encodeCall(harness.policy, (p)));
        require(ok && returned.length == 1184, "policy getter return length");
        require(keccak256(returned) == original, "decoded memory policy canonical bytes");
        C.PolicyExport memory decoded = abi.decode(returned, (C.PolicyExport));
        require(keccak256(abi.encode(decoded)) == original, "policy return decodes unchanged");
    }

    function _assertRecovery(C.RecoveryExport memory r) private view {
        uint256 length = 576 + 160 * r.policy.steps.length;
        bytes memory expected = abi.encode(r);
        bytes32 original = keccak256(expected);
        bytes memory actual = Encoding.recovery(r);
        require(expected.length == length && actual.length == length, "recovery dynamic length");
        require(keccak256(actual) == original, "recovery canonical bytes");
        require(keccak256(abi.encode(r)) == original, "recovery input preserved");
        (bool ok, bytes memory returned) =
            address(harness).staticcall(abi.encodeCall(harness.recovery, (r)));
        require(ok && returned.length == length, "recovery getter return length");
        require(keccak256(returned) == original, "decoded memory recovery canonical bytes");
        C.RecoveryExport memory decoded = abi.decode(returned, (C.RecoveryExport));
        require(keccak256(abi.encode(decoded)) == original, "recovery return decodes unchanged");
    }

    function _policy(bytes32 seed, uint256 counters, uint256 fee, uint8 flags, uint8 modes)
        private
        pure
        returns (C.PolicyExport memory p)
    {
        p.collectionId = uint256(seed);
        p.profile = C.PolicyProfile(modes % 2);
        p.policyOrigin = address(uint160(uint256(_hash(seed, 1))));
        p.policyOriginCodeHash = _hash(seed, 2);
        p.record.configured = (flags & 1) != 0;
        p.record.explicitPolicy = (flags & 2) != 0;
        p.record.frozen = (flags & 4) != 0;
        p.record.mode = P.Mode(modes % 3);
        p.record.securityClass = P.SecurityClass(modes % 2);
        p.record.renderRequirement = P.RenderRequirement((modes / 2) % 2);
        p.record.revision = uint64(counters);
        p.record.providerEpoch = uint32(counters >> 64);
        p.record.policyHash = _hash(seed, 3);
        p.record.contentStateHash = _hash(seed, 4);
        p.record.lastActionId = _hash(seed, 5);
        p.record.artistConsentRecord = _hash(seed, 6);
        p.policy.mode = P.Mode((modes / 3) % 3);
        p.policy.securityClass = P.SecurityClass((modes / 4) % 2);
        p.policy.renderRequirement = P.RenderRequirement((modes / 8) % 2);
        p.policy.provider = address(uint160(uint256(_hash(seed, 7))));
        p.policy.collectionSalt = _hash(seed, 8);
        p.policy.publicRequests = (flags & 8) != 0;
        p.policy.timeoutBlocks = uint64(counters >> 96);
        p.policy.reveal.declared = (flags & 16) != 0;
        p.policy.reveal.requestMode = uint8(counters >> 160);
        p.policy.reveal.revealOwnerRole = _hash(seed, 9);
        p.policy.reveal.requestSLOBlocks = uint64(counters >> 168);
        p.policy.reveal.revealFeePerTokenWei = fee;
        p.policy.maxFreshRecoveryAttempts = uint16(counters >> 232);
        p.policy.recoveryPolicyId = _hash(seed, 10);
        p.providerCodeHash = _hash(seed, 11);
        p.providerConfigHash = _hash(seed, 12);
        p.recovery.policyId = _hash(seed, 13);
        p.recovery.policyHash = _hash(seed, 14);
        p.recovery.maxFreshRecoveryAttempts = uint16(counters);
        p.recovery.revision = uint64(counters >> 16);
        p.recovery.lastActionId = _hash(seed, 15);
    }

    function _recovery(bytes32 seed, uint256 counters, uint256 count, uint8 flags)
        private
        pure
        returns (C.RecoveryExport memory r)
    {
        r.policyId = _hash(seed, 1);
        r.policy.exists = (flags & 1) != 0;
        r.policy.frozen = (flags & 2) != 0;
        r.policy.maxFreshRecoveryAttempts = uint16(counters);
        r.policy.incidentDeclarerRole = _hash(seed, 2);
        r.policy.reasonSchemaHash = _hash(seed, 3);
        r.policy.policyManifestHash = _hash(seed, 4);
        r.policyHash = _hash(seed, 5);
        r.revision = uint64(counters >> 16);
        r.lastActionId = _hash(seed, 6);
        r.policyOrigin = address(uint160(uint256(_hash(seed, 7))));
        r.policyOriginCodeHash = _hash(seed, 8);
        r.successor = address(uint160(uint256(_hash(seed, 9))));
        r.successorCodeHash = _hash(seed, 10);
        r.policy.steps = new R.FreshRecoveryStep[](count);
        for (uint256 i = 0; i < count; ++i) {
            bytes32 stepSeed = _hash(seed, 11 + i);
            // Hash allocations between elements deliberately leave noncontiguous struct memory.
            r.policy.steps[i] = R.FreshRecoveryStep({
                provider: address(uint160(uint256(_hash(stepSeed, 1)))),
                providerEpoch: uint32(uint256(stepSeed)),
                providerConfigHash: _hash(stepSeed, 2),
                notBeforeBlocks: uint64(uint256(stepSeed) >> 32),
                acceptLateOriginalFulfillment: (i + flags) % 2 == 1
            });
        }
    }

    function _hash(bytes32 seed, uint256 field) private pure returns (bytes32) {
        return keccak256(abi.encode(seed, field));
    }
}
