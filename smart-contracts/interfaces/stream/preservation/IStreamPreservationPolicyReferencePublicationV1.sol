// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IERC165 } from "../../../vendor/openzeppelin/IERC165.sol";
import {
    StreamPreservationPolicyReferenceTypesV1 as S
} from "./StreamPreservationPolicyReferenceTypesV1.sol";
import { StreamReferenceRenderTypes as R } from "./StreamReferenceRenderTypes.sol";
import { StreamFinalityScope } from "../finality/StreamArtworkFinalityTypes.sol";

/// @notice COLLECTION preservation V1 BYTE_EXACT observation records; permissionless preparation grants no authority.
interface IStreamPreservationPolicyReferencePublicationV1 is IERC165 {
    event PolicyReferencePublished(
        uint16 schemaVersion,
        bytes32 indexed scopeSubject,
        bytes32 indexed referenceId,
        bytes32 indexed recordHash,
        S.Receipt receipt,
        string manifestURI
    );
    event PolicyReferenceLocked(
        uint16 schemaVersion, bytes32 indexed scopeSubject, R.Lock referenceLock
    );
    function preservationPolicyReferenceProfile() external pure returns (bytes32);
    function core() external view returns (address);
    function metadataHost() external view returns (address);
    function metadataRouter() external view returns (address);
    function snapshots() external view returns (address);
    function archiveCoverage() external view returns (address);
    function dependencies() external view returns (S.Dependencies memory);
    function prepareFileInventory(R.PackageFile[] calldata rows, bool relative)
        external
        returns (bytes32);
    function preparedFileInventory(bytes32 id) external view returns (bytes memory);
    function previewReference(S.Publication calldata p, address recorder)
        external
        view
        returns (bytes32 sourceHash, bytes memory canonical);
    function publishReference(S.Publication calldata p) external returns (bytes32);
    function currentReference(StreamFinalityScope calldata scope)
        external
        view
        returns (S.Receipt memory);
    function referenceRecord(bytes32 hash)
        external
        view
        returns (S.Publication memory, S.Receipt memory);
    function referencePayload(bytes32 hash) external view returns (bytes memory);
    function referenceChunkCount(bytes32 hash) external view returns (uint256);
    function referenceChunkAt(bytes32 hash, uint256 index)
        external
        view
        returns (address pointer, bytes32 chunkHash, uint32 byteSize);
    function referenceSource(bytes32 hash) external view returns (S.SourceFacts memory);
    function referenceCount(StreamFinalityScope calldata scope) external view returns (uint256);
    function referenceAt(StreamFinalityScope calldata scope, uint256 index)
        external
        view
        returns (bytes32);
    function requireCurrent(StreamFinalityScope calldata scope, bytes32 hash, uint64 revision)
        external
        view
        returns (S.Receipt memory);
    function referenceLock(StreamFinalityScope calldata scope) external view returns (R.Lock memory);
    function lockTransition(StreamFinalityScope calldata scope)
        external
        view
        returns (bytes32 actionScope, bytes32 oldHash, bytes32 newHash);
    function lockReference(StreamFinalityScope calldata scope) external;
}
