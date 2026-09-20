// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewPreservationManifestTypesV1 as T
} from "./StreamViewPreservationManifestTypesV1.sol";

interface IStreamViewPreservationOutputManifestV1 {
    event ViewOutputPartPrepared(
        bytes32 indexed recordHash, bytes32 indexed checkpointId, uint64 first, uint16 count
    );
    event ViewOutputManifestStarted(
        bytes32 indexed planHash, bytes32 indexed checkpointId, uint16 partCount
    );
    event ViewOutputManifestAdvanced(bytes32 indexed planHash, uint16 index, bytes32 partRecord);
    event ViewOutputManifestVerified(bytes32 indexed recordHash, bytes32 indexed planHash);
    function configuration() external view returns (T.Configuration memory);
    function configurationHash() external view returns (bytes32);
    function outputProfile() external pure returns (bytes32);
    function preparePart(
        bytes32 checkpointId,
        uint64 first,
        bytes32 artifactHash,
        bytes32 coverageHash,
        bytes32 artistId
    ) external returns (bytes32);
    function beginManifest(
        bytes32 checkpointId,
        bytes32 artifactHash,
        bytes32 coverageHash,
        bytes32 artistId
    ) external returns (bytes32);
    function verifyNextPart(bytes32 planHash, bytes32 partRecord)
        external
        returns (bytes32 recordHash);
    function partRecord(bytes32 recordHash) external view returns (T.Part memory);
    function manifestPlan(bytes32 planHash) external view returns (T.Plan memory);
    function manifestRecord(bytes32 recordHash) external view returns (T.Plan memory);
    function manifestPart(bytes32 recordHash, uint256 index)
        external
        view
        returns (T.Descriptor memory);
    function requireCurrentManifest(bytes32 recordHash, bytes32 artistId)
        external
        view
        returns (T.Plan memory);
}
