// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamFinalityScope } from "./StreamArtworkFinalityTypes.sol";

/// @notice Complete preserved STATIC output-row inventory; not preservation of the full output bytes.
interface IStreamStaticOutputManifest {
    struct Manifest {
        bytes32 checkpointHash;
        bytes32 checkpointStateHash;
        bytes32 artifactHash;
        bytes32 coverageHash;
        bytes32 artistId;
        bytes32 contentRoot;
        bytes32 outputRoot;
        bytes32 manifestHash;
        StreamFinalityScope scope;
        uint64 tokenCount;
        uint64 byteLength;
    }

    struct Plan {
        Manifest manifest;
        uint64 nextIndex;
        bytes32 recordHash;
    }
    error InvalidOutputManifest();
    error OutputManifestComponentChanged(address target);
    error OutputManifestReadFailed(address target, bytes4 selector);
    error OutputManifestParentGas(uint256 available, uint256 required);
    error OutputManifestUnknown(bytes32 hash);
    error OutputManifestBatch(uint256 count);
    error OutputManifestMismatch(uint256 index);
    event OutputManifestStarted(uint16 schemaVersion, bytes32 indexed planHash, Manifest manifest);
    event OutputManifestAdvanced(
        uint16 schemaVersion, bytes32 indexed planHash, uint64 firstIndex, uint64 nextIndex
    );
    event OutputManifestVerified(
        uint16 schemaVersion,
        bytes32 indexed recordHash,
        bytes32 indexed planHash,
        Manifest manifest
    );
    function core() external view returns (address);
    function contentCheckpoint() external view returns (address);
    function artifactCoverage() external view returns (address);
    function beginManifest(
        bytes32 checkpointHash,
        bytes32 artifactHash,
        bytes32 coverageHash,
        bytes32 artistId
    ) external returns (bytes32);
    function verifyNextOutputs(bytes32 planHash, uint256 count) external returns (bytes32);
    function manifestPlan(bytes32 planHash) external view returns (Plan memory);
    function manifestRecord(bytes32 recordHash) external view returns (Manifest memory);
    function requireCurrentManifest(bytes32 recordHash, bytes32 artistId)
        external
        view
        returns (Manifest memory);
}
