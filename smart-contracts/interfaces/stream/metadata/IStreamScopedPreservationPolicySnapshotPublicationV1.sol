// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as S
} from "./StreamScopedPreservationPolicySnapshotTypesV1.sol";
import { StreamFinalityScope } from "../finality/StreamArtworkFinalityTypes.sol";

/// @notice Distinct admitted preservation-policy source snapshots for TOKEN, RELEASE and SEASON.
/// @dev Neither membership nor this publication grants Artist CONTENT_ROOT or alternate VIEW authority.
interface IStreamScopedPreservationPolicySnapshotPublicationV1 is IERC165 {
    event ScopedPolicySnapshotPublished(
        uint16 schemaVersion,
        bytes32 indexed scopeSubject,
        bytes32 indexed snapshotId,
        bytes32 indexed recordHash,
        S.Publication publication,
        S.Receipt receipt
    );
    event ScopedPolicySnapshotLocked(
        uint16 schemaVersion, bytes32 indexed scopeSubject, S.Lock snapshotLock
    );

    function scopedPreservationPolicySnapshotProfile() external pure returns (bytes32);
    function core() external view returns (address);
    function metadataHost() external view returns (address);
    function dependencies() external view returns (S.Dependencies memory);
    function previewSnapshot(S.Publication calldata publication, address publisher)
        external
        view
        returns (bytes32 sourceHash, bytes memory canonical);
    function publishSnapshot(S.Publication calldata publication) external returns (bytes32);
    function currentSnapshot(StreamFinalityScope calldata scope)
        external
        view
        returns (S.Receipt memory);
    function snapshotRecord(bytes32 recordHash)
        external
        view
        returns (S.Publication memory, S.Receipt memory);
    function snapshotPayload(bytes32 recordHash) external view returns (bytes memory);
    function requireCurrent(StreamFinalityScope calldata scope, bytes32 recordHash, uint64 revision)
        external
        view
        returns (S.Receipt memory);
    function lockTransition(StreamFinalityScope calldata scope)
        external
        view
        returns (bytes32 actionScope, bytes32 oldState, bytes32 newState);
    function lockSnapshot(StreamFinalityScope calldata scope) external;
    function snapshotLock(StreamFinalityScope calldata scope) external view returns (S.Lock memory);
    function snapshotCount(StreamFinalityScope calldata scope) external view returns (uint256);
    function snapshotAt(StreamFinalityScope calldata scope, uint256 index)
        external
        view
        returns (bytes32);
}
