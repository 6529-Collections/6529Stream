// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Canonical [LTA-EXPORT] discovery surface, hosted on the governance Executor.
/// @dev ERC-165 ID is 0x77faad4f. Writers and history are separate capabilities;
///      extending them must not change this locked read interface or event schemas.
interface IStreamStateExportPublisher {
    event StateExportPublished(
        uint16 schemaVersion,
        uint256 indexed blockNumber,
        bytes32 indexed exportHash,
        bytes32 indexed manifestHash,
        bytes32 blockHash,
        string manifestURI
    );

    event StateExportChallenged(
        uint16 schemaVersion,
        bytes32 indexed exportHash,
        bytes32 indexed challengeHash,
        address indexed challenger,
        string challengeURI
    );

    event StateExportSuperseded(
        uint16 schemaVersion,
        bytes32 indexed oldExportHash,
        bytes32 indexed newExportHash,
        bytes32 indexed reasonHash,
        string reasonURI
    );

    /// @notice Most recently published export, or zero values before the first publication.
    /// @dev Publication commits a discoverable claim, not proof of offchain data correctness.
    function latestStateExport()
        external
        view
        returns (
            uint256 blockNumber,
            bytes32 blockHash,
            bytes32 exportHash,
            bytes32 manifestHash,
            string memory manifestURI
        );
}
