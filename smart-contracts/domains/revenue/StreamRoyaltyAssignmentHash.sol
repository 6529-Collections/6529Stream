// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamRoyaltyResolver } from "../../interfaces/stream/revenue/IStreamRoyaltyResolver.sol";
import { IStreamSplitFactory } from "../../interfaces/stream/revenue/IStreamSplitFactory.sol";

import { StreamRoyaltyContinuityState as Continuity } from "./StreamRoyaltyContinuityState.sol";

/// @notice Original canonical royalty hashes, shared by live and prepared snapshot paths.
/// @dev Fixed library calls retain actual Resolver address(this). Mode consent stays separate.
library StreamRoyaltyAssignmentHash {
    function assignment(
        IStreamSplitFactory splitFactory,
        IStreamRoyaltyResolver.RoyaltyConfig memory item,
        uint8 scope,
        uint256 scopeId
    ) public view returns (bytes32) {
        return assignmentForOrigin(
            splitFactory, item, scope, scopeId, Continuity.origin(scope, scopeId, item.frozen)
        );
    }

    /// @notice Reproduce the immutable original Resolver preimage during a verified handoff.
    function assignmentForOrigin(
        IStreamSplitFactory splitFactory,
        IStreamRoyaltyResolver.RoyaltyConfig memory item,
        uint8 scope,
        uint256 scopeId,
        address hashOrigin
    ) public view returns (bytes32) {
        bytes32 resolverContext = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_ASSIGNMENT_RESOLVER_CONTEXT_V1"),
                hashOrigin,
                address(splitFactory),
                address(splitFactory.assetPolicyRegistry()),
                splitFactory.splitWalletRuntimeCodeHash()
            )
        );
        bytes32 scopeContext = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_ASSIGNMENT_SCOPE_CONTEXT_V1"),
                keccak256("ROYALTY_ERC2981"),
                scope,
                scopeId,
                uint8(1)
            )
        );
        bytes32 entriesHash = item.profileId == bytes32(0)
            ? bytes32(0)
            : splitFactory.profileEntriesHash(item.profileId);
        bytes32 metadataHash = item.profileId == bytes32(0)
            ? bytes32(0)
            : splitFactory.profileMetadataURIHash(item.profileId);
        // PROFILE type always has a profile context, including an explicitly disabled zero profile.
        bytes32 profileContext = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_ASSIGNMENT_PROFILE_CONTEXT_V1"),
                item.wallet,
                entriesHash,
                metadataHash
            )
        );
        bytes32 pointerContext = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROYALTY_ASSIGNMENT_POINTER_CONTEXT_V1"),
                item.profileId,
                profileContext,
                item.royaltyBps
            )
        );
        // This resolver advertises no loosening: the canonical assignment-policy input is zero.
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_ASSIGNMENT_V1"),
                block.chainid,
                resolverContext,
                scopeContext,
                pointerContext,
                bytes32(0),
                item.frozen
            )
        );
    }

    function policy(
        uint256 collectionId,
        uint8 scope,
        uint256 scopeId,
        IStreamRoyaltyResolver.RoyaltyConfig memory item,
        bytes32 assignmentHash
    ) public view returns (bytes32) {
        return policyForOrigin(
            collectionId,
            scope,
            scopeId,
            item,
            assignmentHash,
            Continuity.origin(scope, scopeId, item.frozen)
        );
    }

    function policyForOrigin(
        uint256 collectionId,
        uint8 scope,
        uint256 scopeId,
        IStreamRoyaltyResolver.RoyaltyConfig memory item,
        bytes32 assignmentHash,
        address hashOrigin
    ) public view returns (bytes32) {
        if (!item.configured) return bytes32(0);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROYALTY_POLICY_V1"),
                block.chainid,
                hashOrigin,
                scope == 0 ? uint256(0) : collectionId,
                scope == 2 ? scopeId : uint256(0),
                item.profileId,
                item.wallet,
                item.royaltyBps,
                assignmentHash
            )
        );
    }
}
