// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Immutable provenance of a completed royalty import, independent of later new mints.
/// @dev This receipt does not grant Artist consent. New terms name the actual selected consumer.
interface IStreamRoyaltyConsumerContinuity {
    struct Receipt {
        uint8 status;
        address core;
        address factory;
        address origin;
        bytes32 originRuntimeHash;
        address source;
        bytes32 sourceRuntimeHash;
        bytes32 manifestHash;
        bytes32 beginActionId;
        bytes32 importedHeaderHash;
    }

    function royaltyConsumerContinuity() external view returns (Receipt memory);

    /// @notice Original canonical hash domains; current consumer identity remains unchanged.
    function royaltyHashOrigins(uint8 scope, uint256 scopeId, uint256 collectionId)
        external view returns (address assignmentOrigin, address electionOrigin);
}
