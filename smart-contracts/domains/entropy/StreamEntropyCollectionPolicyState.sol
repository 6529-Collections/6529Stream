// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamEntropyCollectionPolicy as P
} from "../../interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";

/// @notice Additive policy storage; no original Coordinator slot or struct is extended.
library StreamEntropyCollectionPolicyState {
    bytes32 internal constant FAMILY = keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1");
    bytes32 private constant SLOT = keccak256("6529STREAM_ENTROPY_COLLECTION_POLICY_STORAGE_V1");

    struct Entry {
        uint64 revision;
        P.Mode mode;
        P.SecurityClass securityClass;
        P.RenderRequirement renderRequirement;
        bytes32 policyHash;
        bytes32 lastActionId;
        bytes32 artistConsentRecord;
    }

    struct Store {
        mapping(uint256 => Entry) entries;
        mapping(uint256 => mapping(bytes32 => bool)) actions;
        mapping(bytes32 => bool) consents;
    }

    function store() internal pure returns (Store storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function explicitPolicy(uint256 id) internal view returns (bool) {
        return store().entries[id].revision != 0;
    }

    function requireLegacy(uint256 id) internal view {
        if (explicitPolicy(id)) revert P.ExplicitCollectionPolicyRequired(id);
    }

    function mode(uint256 id) internal view returns (P.Mode) {
        Entry storage e = store().entries[id];
        return e.revision == 0 ? P.Mode.ASYNC : e.mode;
    }

    function requireAsync(uint256 id) internal view {
        P.Mode selected = mode(id);
        if (selected != P.Mode.ASYNC) revert P.UnsupportedEntropyMode(selected);
    }

    function contentState(bytes32 policyHash, bool frozen) internal pure returns (bytes32) {
        return keccak256(abi.encode(FAMILY, policyHash, frozen));
    }
}
