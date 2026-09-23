// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamFinalityScope } from "./StreamArtworkFinalityTypes.sol";
import { StreamViewAdoptionTypes as V } from "../metadata/StreamViewAdoptionTypes.sol";
import {
    StreamViewPolicyTypesV2 as Policy
} from "../../../domains/metadata/StreamViewPolicyTypesV2.sol";

/// @notice Distinct exact-output VIEW observations, never COLLECTION evidence or new Artist authority.
library StreamViewPolicyCheckpointTypesV2 {
    bytes32 internal constant PROFILE =
        keccak256("6529STREAM_ADOPTED_POLICY_VIEW_OUTPUT_CHECKPOINT_V2");
    bytes32 internal constant SOURCE =
        keccak256("6529STREAM_ADOPTED_POLICY_VIEW_CHECKPOINT_SOURCE_V2");
    bytes32 internal constant ROW = keccak256("6529STREAM_ADOPTED_POLICY_VIEW_OUTPUT_ROW_V2");

    uint8 internal constant CURRENT = 1;
    uint8 internal constant RETAINED_BURNED = 2;

    struct Configuration {
        address core;
        bytes32 coreCodeHash;
        address router;
        bytes32 routerCodeHash;
        address authority;
        bytes32 authorityCodeHash;
        address serving;
        bytes32 servingCodeHash;
        bytes32 servingConfigurationHash;
        uint256 chainId;
        uint32 readGas;
        uint32 servingGas;
    }

    /// @dev Constructed only from the actual Router's retained and independently current source.
    struct Source {
        V.Record adoption;
        Policy.Binding policy;
        bytes32 contextHash;
    }

    struct Output {
        uint64 index;
        uint256 tokenId;
        uint256 collectionSerial;
        uint8 lifecycle;
        bool burned;
        uint8 servingKind;
        bytes32 tokenDataHash;
        Policy.Entropy entropy;
        bytes32 jsonHash;
        bytes32 htmlHash;
        uint32 jsonBytes;
        uint32 htmlBytes;
    }

    struct Plan {
        StreamFinalityScope scope;
        bytes32 adoptionRecord;
        bytes32 sourceContextHash;
        bytes32 membershipHash;
        bytes32 policyChainHash;
        uint64 tokenCount;
        uint64 nextIndex;
        bytes32 rowChain;
        bytes32 outputRoot;
    }
    error InvalidViewCheckpoint();
    error ViewCheckpointDependency(address target);
    error ViewCheckpointChanged(bytes32 id);
    error ViewCheckpointToken(uint256 tokenId);
    error ViewCheckpointIndex(uint256 index);
}
