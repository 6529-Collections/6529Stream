// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamEntropyPolicyConsumerTypes as P
} from "../../interfaces/stream/entropy/StreamEntropyPolicyConsumerTypes.sol";

/// @notice Closed V2 adopted VIEW vocabulary. No token, entropy or Artist authority is inferred.
library StreamViewPolicyTypesV2 {
    bytes32 internal constant PROFILE = keccak256("6529STREAM_STATIC_ADOPTED_POLICY_VIEW_V2");
    bytes32 internal constant CONTEXT = keccak256("STREAM_ADOPTED_POLICY_VIEW_CONTEXT_V2");

    struct Binding {
        address core;
        bytes32 coreCodeHash;
        address factory;
        bytes32 factoryCodeHash;
        address sourceSet;
        bytes32 sourceSetCodeHash;
        uint256 chainId;
        StreamFinalityScope scope;
        StreamScopeMembershipFacts membership;
        bytes32 inventoryPlan;
        bytes32 inventoryHash;
        bytes32 policyChainHash;
        uint256 policyCount;
    }

    /// @dev Derived from the actual original coordinator and constructor-retained rule only.
    struct Entropy {
        address coordinator;
        bytes32 coordinatorCodeHash;
        bytes32 policyHash;
        bool explicitPolicy;
        P.Policy policy;
        uint8 status;
        bytes32 seed;
        bool finalized;
        bool terminal;
    }
}
