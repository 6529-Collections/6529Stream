// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityViewPreservationBindingTypesV1 as Basic
} from "./StreamFinalityViewPreservationBindingTypesV1.sol";
import {
    IStreamViewPreservationFinalitySourcesV1 as Sources
} from "./IStreamViewPreservationFinalitySourcesV1.sol";

/// @notice Additional complete source admission without changing the original basic receipt.
/// @dev Both paths share one unbound/bound guard. Source admission is not current evidence.
library StreamFinalityViewPreservationCompleteBindingTypesV1 {
    bytes32 internal constant PROFILE =
        keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_BINDING_V1");

    error ViewPreservationCompleteBindingUnavailable();
    error InvalidViewPreservationCompleteBinding();

    /// @dev No future action ID, basic record hash or execution timestamp enters a proposal.
    function proposalHash(Basic.Receipt memory basic, Sources.Receipt memory complete)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_PROPOSAL_V1"),
                Basic.proposalHash(basic),
                complete.selection,
                complete.referenceDependenciesHash,
                complete.inventoryDependenciesHash,
                complete.bundleDependenciesHash
            )
        );
    }

    function receiptHash(uint256 chainId, address provider, Sources.Receipt memory r)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_RECEIPT_V1"),
                chainId,
                provider,
                r.selection,
                r.referenceDependenciesHash,
                r.inventoryDependenciesHash,
                r.bundleDependenciesHash,
                r.basicBindingRecordHash,
                r.actionId,
                r.boundAt
            )
        );
    }

    function transition(
        uint256 chainId,
        address provider,
        Basic.Receipt memory basic,
        Sources.Receipt memory complete
    ) internal pure returns (Basic.Transition memory t) {
        t.scopeHash = keccak256(abi.encode(PROFILE, chainId, provider, basic.capabilityHash));
        t.oldValueHash = keccak256(abi.encode(PROFILE, basic.capabilityHash, false));
        t.newValueHash = proposalHash(basic, complete);
    }
}
