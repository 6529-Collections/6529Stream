// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamFinalityScope } from "../finality/StreamArtworkFinalityTypes.sol";
import { StreamScopedRenderCriticalTypes as Scoped } from "./StreamScopedRenderCriticalTypes.sol";
import { StreamPreservationInventoryTypes as T } from "./StreamPreservationInventoryTypes.sol";
import { StreamRenderCriticalSourceTypes as S } from "./StreamRenderCriticalSourceTypes.sol";

/// @notice Complete scope-bound native inventory, distinct from the original COLLECTION profile.
/// @dev A current completed inventory authenticates source closure, not archive coverage or finality.
interface IStreamScopedRenderCriticalInventory {
    event ScopedInventoryStarted(
        uint16 schemaVersion, bytes32 indexed id, StreamFinalityScope scope, bytes32 contextHash
    );
    event ScopedInventorySegmentRecorded(
        uint16 schemaVersion,
        bytes32 indexed id,
        uint64 indexed index,
        T.Segment segment,
        T.Item[] items
    );
    event ScopedInventoryCompleted(
        uint16 schemaVersion,
        bytes32 indexed id,
        bytes32 indexed evidenceHash,
        Scoped.Evidence evidence
    );
    function core() external view returns (address);
    function metadataHost() external view returns (address);
    function metadataRouter() external view returns (address);
    function dependencies() external view returns (S.Dependencies memory);
    function dependencyHash() external view returns (bytes32);
    function beginInventory(StreamFinalityScope calldata scope) external returns (bytes32);
    function plan(bytes32 id) external view returns (Scoped.Plan memory);
    function sourceContext(bytes32 id) external view returns (Scoped.Context memory);
    function inventorySegment(bytes32 id, uint64 index) external view returns (T.Segment memory);
    function inventoryEvidence(bytes32 id) external view returns (Scoped.Evidence memory);
    function requireCurrent(StreamFinalityScope calldata scope)
        external
        view
        returns (Scoped.Evidence memory);
}
