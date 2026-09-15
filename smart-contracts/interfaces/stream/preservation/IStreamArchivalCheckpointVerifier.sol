// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArchivalTypes as A } from "./StreamArchivalTypes.sol";

/// @notice Quorum-authenticated network facts plus native transaction/data-path verification.
interface IStreamArchivalCheckpointVerifier {
    event ArchivalCheckpointRecorded(
        uint16 schemaVersion,
        bytes32 indexed recordHash,
        bytes32 indexed transactionId,
        bytes32 indexed configurationHash,
        bytes32 checkpointDigest,
        bytes32 payloadDigest,
        bytes32 contentHash,
        uint64 recordedAt
    );

    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function profileHash() external view returns (bytes32);
    function configurationHash() external view returns (bytes32);
    function networkId() external view returns (bytes32);
    function quorum() external view returns (uint8);
    function observers() external view returns (A.Observer[] memory);
    function checkpointDigest(A.Checkpoint calldata checkpoint) external view returns (bytes32);
    function recordCheckpoint(
        A.Checkpoint calldata checkpoint,
        bytes calldata transactionPath,
        bytes calldata dataPath,
        bytes calldata payload,
        A.ObserverProof[] calldata certificate
    ) external returns (bytes32 recordHash);
    function checkpointFacts(bytes32 recordHash) external view returns (A.CheckpointFacts memory);
    function checkpointRecord(bytes32 recordHash) external view returns (A.CheckpointRecord memory);
}
