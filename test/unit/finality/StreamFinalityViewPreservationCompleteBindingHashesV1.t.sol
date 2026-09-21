// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityViewPreservationBindingTypesV1 as Basic
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityViewPreservationBindingTypesV1.sol";
import {
    StreamFinalityViewPreservationCompleteBindingTypesV1 as Complete
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityViewPreservationCompleteBindingTypesV1.sol";
import {
    IStreamViewPreservationFinalitySourcesV1 as Sources
} from "../../../smart-contracts/interfaces/stream/finality/IStreamViewPreservationFinalitySourcesV1.sol";

/// @dev Pure commitment tests only. These constructed tuples do not establish producer admission,
/// governance execution, current evidence, or validity of any selected contract.
contract StreamFinalityViewPreservationCompleteBindingHashesV1Test {
    function testCompleteProposalHasLiteralPreimageAndSeparateAuthorityScope() public pure {
        (Basic.Receipt memory b, Sources.Receipt memory c) = _candidate();
        bytes32 inner = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_PROPOSAL_V1"),
                b.capabilityHash,
                b.configuration,
                b.declaration,
                b.dependencies,
                b.dependenciesHash,
                b.workersHash
            )
        );
        bytes32 full = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_PROPOSAL_V1"),
                inner,
                c.selection,
                c.referenceDependenciesHash,
                c.inventoryDependenciesHash,
                c.bundleDependenciesHash
            )
        );
        require(Complete.proposalHash(b, c) == full && full != inner);
        Basic.Transition memory complete = Complete.transition(7, address(8), b, c);
        Basic.Transition memory basic = Basic.transition(7, address(8), b);
        bytes32 profile = keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_BINDING_V1");
        require(
            complete.scopeHash
                == keccak256(abi.encode(profile, uint256(7), address(8), b.capabilityHash))
        );
        require(complete.oldValueHash == keccak256(abi.encode(profile, b.capabilityHash, false)));
        require(complete.newValueHash == full);
        require(
            complete.scopeHash != basic.scopeHash && complete.oldValueHash != basic.oldValueHash
        );
        require(complete.newValueHash != basic.newValueHash);
    }

    function testCompleteProposalCommitsEverySelectionAndInitialDependencyField() public pure {
        (Basic.Receipt memory b, Sources.Receipt memory c) = _candidate();
        bytes32 initial = Complete.proposalHash(b, c);
        // Selection has six words; the next three are the initial dependency hashes.
        for (uint256 i; i < 9; ++i) {
            bytes memory encoded = abi.encode(c);
            _differentWord(encoded, i);
            Sources.Receipt memory changed = abi.decode(encoded, (Sources.Receipt));
            require(Complete.proposalHash(b, changed) != initial);
        }
        b.configuration.snapshotHost = address(99);
        require(Complete.proposalHash(b, c) != initial);
        (b, c) = _candidate();
        b.declaration.sourceGas += 1;
        require(Complete.proposalHash(b, c) != initial);
    }

    function testCompleteProposalExcludesFutureExecutionAndReceiptFields() public pure {
        (Basic.Receipt memory b, Sources.Receipt memory c) = _candidate();
        bytes32 initial = Complete.proposalHash(b, c);
        b.actionId = keccak256("future action");
        b.boundAt = 200;
        b.recordHash = keccak256("future basic record");
        c.basicBindingRecordHash = b.recordHash;
        c.actionId = b.actionId;
        c.boundAt = b.boundAt;
        c.recordHash = keccak256("future complete record");
        require(Complete.proposalHash(b, c) == initial);
    }

    function testCompleteReceiptCommitsSameActionBasicRecordAndDomain() public pure {
        (Basic.Receipt memory b, Sources.Receipt memory c) = _candidate();
        b.actionId = keccak256("one complete action");
        b.boundAt = 123;
        b.recordHash = Basic.receiptHash(b);
        c.basicBindingRecordHash = b.recordHash;
        c.actionId = b.actionId;
        c.boundAt = b.boundAt;
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_RECEIPT_V1"),
                uint256(7),
                address(8),
                c.selection,
                c.referenceDependenciesHash,
                c.inventoryDependenciesHash,
                c.bundleDependenciesHash,
                b.recordHash,
                b.actionId,
                b.boundAt
            )
        );
        require(Complete.receiptHash(7, address(8), c) == expected);
        require(Complete.receiptHash(8, address(8), c) != expected);
        require(Complete.receiptHash(7, address(9), c) != expected);
        // All twelve preceding words are committed; the thirteenth is the output record hash.
        for (uint256 i; i < 12; ++i) {
            bytes memory encoded = abi.encode(c);
            _differentWord(encoded, i);
            Sources.Receipt memory changed = abi.decode(encoded, (Sources.Receipt));
            require(Complete.receiptHash(7, address(8), changed) != expected);
        }
        c.recordHash = expected;
        require(Complete.receiptHash(7, address(8), c) == expected);
        require(c.recordHash == expected); // Hashing must not normalize the caller's memory.
    }

    function _differentWord(bytes memory encoded, uint256 index) private pure {
        // Flip only the low bit, retaining canonical address and uint64 padding.
        assembly {
            let word := add(add(encoded, 32), mul(index, 32))
            mstore(word, xor(mload(word), 1))
        }
    }

    function _candidate() private pure returns (Basic.Receipt memory b, Sources.Receipt memory c) {
        b.capabilityHash = keccak256("basic capability");
        b.configuration = Basic.Configuration(
            address(1),
            bytes32(uint256(2)),
            16000000,
            address(3),
            bytes32(uint256(4)),
            address(5),
            bytes32(uint256(6))
        );
        b.declaration.views = address(7);
        b.declaration.viewsCodeHash = bytes32(uint256(8));
        b.declaration.membership = address(9);
        b.declaration.membershipCodeHash = bytes32(uint256(10));
        b.declaration.readGas = 1000000;
        b.declaration.sourceGas = 4000000;
        b.dependencies.chainId = 7;
        b.dependenciesHash = keccak256(abi.encode(b.dependencies));
        b.workersHash = keccak256("worker pins");
        c.selection = Sources.Selection(
            address(11),
            bytes32(uint256(12)),
            address(13),
            bytes32(uint256(14)),
            address(15),
            bytes32(uint256(16))
        );
        c.referenceDependenciesHash = keccak256("reference dependencies");
        c.inventoryDependenciesHash = keccak256("inventory dependencies");
        c.bundleDependenciesHash = keccak256("bundle dependencies");
    }
}
