// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistOnboardingTypes.sol";
import "./StreamArtistSanctionTypes.sol";
import "../finality/StreamArtworkFinalityTypes.sol";
import "../finality/StreamFinalityGovernanceTypes.sol";
import "../finality/StreamFinalitySanctionArchiveTypes.sol";

/// @notice Permissionless confirmation facts, distinct from a new sanction authorization.
library StreamArtistSanctionConfirmationTypes {
    struct Transition {
        uint256 collectionId;
        bytes32 artistId;
        uint64 bindingGeneration;
        bytes32 sanctionRecordHash;
        bytes32 finalityRecordHash;
        uint8 priorAttributionState;
    }

    struct Observation {
        StreamArtistOnboardingTypes.Binding binding_;
        uint8 priorAttributionState;
        StreamArtistSanctionTypes.Record sanction;
        StreamCollectionFinalityRecord finalityRecord;
        StreamFinalityComponentExpectation[] components;
        StreamFinalityExecutionWitness executionWitness;
        StreamFinalitySanctionArchiveWitness archiveWitness;
        bytes32 rawReadHash;
    }

    /// @notice Compact evidence for the full canonically checked record retained by Finality.
    /// @dev fullRecordHash commits abi.encode of that complete record, including the immutable URI.
    struct FinalityRecordEvidence {
        bytes32 finalityRecordHash;
        bytes32 manifestContentHash;
        bytes32 manifestURIHash;
        bytes32 componentsHash;
        address manifestPointer;
        uint64 finalizedAt;
        bytes32 fullRecordHash;
    }

    function scope(Transition memory p) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(keccak256("6529STREAM_ARTIST_SANCTION_FINALIZATION_TRANSITION_V1"), p)
        );
    }

    error InvalidSanctionConfirmation();
    error SanctionConfirmationReadFailed(address target);
    error SanctionConfirmationParentGas(uint256 available, uint256 required);
}
