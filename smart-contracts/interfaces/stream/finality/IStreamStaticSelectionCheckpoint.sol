// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamFinalityScope } from "./StreamArtworkFinalityTypes.sol";
import { IStreamStaticMetadataRouter as S } from "../metadata/IStreamStaticMetadataRouter.sol";

/// @notice Complete ordered selection evidence from an authoritative scope, never a supplied token list.
/// @dev A selection checkpoint is a reproducible source candidate, not content-root, opcode or finality acceptance.
interface IStreamStaticSelectionCheckpoint {
    struct Plan {
        StreamFinalityScope scope;
        bytes32 membershipHash;
        bytes32 collectionStateHash;
        uint64 tokenCount;
        uint64 nextIndex;
        bytes32 selectionRoot;
    }

    struct TokenSelection {
        uint256 tokenId;
        bytes32 configRecordHash;
        bytes32 configHash;
        bytes32 sourceSnapshotHash;
        bytes32 rawSourceHash;
        S.Selection selection;
        address[6] sources;
        bytes32[6] sourceCodeHashes;
    }
    error StaticCheckpointConfiguration();
    error StaticCheckpointDependency(address target);
    error StaticCheckpointRead(address target, bytes4 selector);
    error StaticCheckpointInputChanged(bytes32 id);
    error StaticCheckpointUnknown(bytes32 id);
    error StaticCheckpointIncomplete(bytes32 id);
    error StaticCheckpointBatch(uint256 count);
    error StaticCheckpointToken(uint256 tokenId);
    error StaticCheckpointIndex(uint256 index);
    event StaticSelectionStarted(uint16 schemaVersion, bytes32 indexed id, Plan plan);
    event StaticSelectionAppended(
        uint16 schemaVersion,
        bytes32 indexed id,
        uint64 indexed index,
        TokenSelection selection,
        bytes32 rowHash
    );
    event StaticSelectionCompleted(
        uint16 schemaVersion, bytes32 indexed id, bytes32 selectionRoot, uint64 tokenCount
    );
    function core() external view returns (address);
    function metadataRouter() external view returns (address);
    function scopeMembership() external view returns (address);
    function begin(StreamFinalityScope calldata scope) external returns (bytes32 id);
    function append(bytes32 id, uint256 maximumTokens) external;
    function checkpoint(bytes32 id) external view returns (Plan memory);
    function selectionAt(bytes32 id, uint256 index) external view returns (TokenSelection memory);
    /// @notice Revalidates current collection input and full authoritative scope; source rows remain historical facts.
    function requireCurrentCheckpoint(bytes32 id) external view returns (Plan memory);
}
