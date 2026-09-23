// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArchivalTypes as A } from "./StreamArchivalTypes.sol";
import { StreamExternalArtifactTypes as E } from "./StreamExternalArtifactTypes.sol";

interface IStreamExternalArtifactCheckpointVerifier {
    event ExternalObjectCheckpointRecorded(
        uint16 schemaVersion,
        bytes32 indexed recordHash,
        bytes32 indexed transactionId,
        bytes32 indexed configurationHash,
        bytes32 checkpointDigest,
        bytes32 dataRoot,
        uint64 dataSize,
        uint64 recordedAt
    );
    function supportsInterface(bytes4 id) external view returns (bool);
    function profileHash() external view returns (bytes32);
    function networkId() external view returns (bytes32);
    function configurationHash() external view returns (bytes32);
    function quorum() external view returns (uint8);
    function observers() external view returns (A.Observer[] memory);
    function checkpointDigest(A.Checkpoint calldata checkpoint) external view returns (bytes32);
    function recordCheckpoint(
        A.Checkpoint calldata checkpoint,
        bytes calldata transactionPath,
        bytes calldata firstDataPath,
        bytes calldata lastDataPath,
        A.ObserverProof[] calldata certificate
    ) external returns (bytes32);
    function checkpointFacts(bytes32 hash) external view returns (E.NativeFacts memory);
    function checkpointRecord(bytes32 hash) external view returns (E.NativeRecord memory);
}
