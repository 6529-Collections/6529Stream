// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamFinalityScope } from "../finality/StreamArtworkFinalityTypes.sol";
import {
    StreamViewPreservationRenderCriticalTypesV1 as Scoped
} from "./StreamViewPreservationRenderCriticalTypesV1.sol";
import { StreamPreservationInventoryTypes as T } from "./StreamPreservationInventoryTypes.sol";
import { StreamRenderCriticalSourceTypes as S } from "./StreamRenderCriticalSourceTypes.sol";

import {
    IStreamScopedContentRootPublication as Root
} from "../metadata/IStreamScopedContentRootPublication.sol";
import { StreamWorkRecordTypes } from "../metadata/StreamWorkRecordTypes.sol";
import { StreamRightsRecordTypes } from "../metadata/StreamRightsRecordTypes.sol";
import { StreamConservationRecordTypes } from "../metadata/StreamConservationRecordTypes.sol";

/// @notice Complete adopted VIEW preservation inventory, distinct from every prior inventory profile.
/// @dev A current completed inventory authenticates source closure, not archive coverage or finality.
interface IStreamViewPreservationRenderCriticalInventoryV1 {
    event ViewPreservationInventoryStarted(
        uint16 schemaVersion, bytes32 indexed id, StreamFinalityScope scope, bytes32 contextHash
    );
    event ViewPreservationInventorySegmentRecorded(
        uint16 schemaVersion,
        bytes32 indexed id,
        uint64 indexed index,
        T.Segment segment,
        T.Item[] items
    );
    event ViewPreservationInventoryCompleted(
        uint16 schemaVersion,
        bytes32 indexed id,
        bytes32 indexed evidenceHash,
        Scoped.Evidence evidence
    );
    function core() external view returns (address);
    function metadataHost() external view returns (address);
    function metadataRouter() external view returns (address);
    function snapshots() external view returns (address);
    function referencePublisher() external view returns (address);
    function artifactCoverage() external view returns (address);
    function externalCoverage() external view returns (address);
    function dependencies() external view returns (S.Dependencies memory);
    function dependencyHash() external view returns (bytes32);
    function beginInventory(StreamFinalityScope calldata scope) external returns (bytes32);
    function appendNative(bytes32 id, uint64 maximum) external;
    function appendReference(bytes32 id, uint64 maximum) external;
    function appendWork(
        bytes32 id,
        StreamWorkRecordTypes.Description calldata witness,
        address originalActor
    ) external;
    function appendRights(bytes32 id, StreamRightsRecordTypes.Statement calldata witness) external;
    function appendIntent(
        bytes32 id,
        StreamConservationRecordTypes.Intent calldata witness,
        address originalActor
    ) external;
    function appendIntentWaiver(
        bytes32 id,
        StreamConservationRecordTypes.IntentWaiver calldata witness,
        address originalActor
    ) external;
    function appendInterview(
        bytes32 id,
        StreamConservationRecordTypes.Interview calldata witness,
        address originalActor
    ) external;
    function appendInterviewWaiver(bytes32 id) external;
    function appendRootAuthorization(
        bytes32 id,
        address actor,
        uint64 observedAt,
        Root.Aggregate calldata originalAggregate,
        bytes32 originalLegacyFamilyHash
    ) external;
    function appendDefinition(bytes32 id) external;
    function appendArtwork(bytes32 id) external;
    function appendRenderer(bytes32 id) external;
    function appendPreservationAdmission(bytes32 id) external;
    function appendTokenOutput(bytes32 id) external;
    function inventoryProfile() external pure returns (bytes32);
    function supportsInterface(bytes4 id) external pure returns (bool);
    function sealInventory(bytes32 id) external returns (Scoped.Evidence memory);
    function tokenProgress(bytes32 id) external view returns (Scoped.TokenProgress memory);
    function requireFullDefinitionBytes(bytes32 id) external view;
    function plan(bytes32 id) external view returns (Scoped.Plan memory);
    function sourceContext(bytes32 id) external view returns (Scoped.Context memory);
    function inventorySegment(bytes32 id, uint64 index) external view returns (T.Segment memory);
    function inventoryEvidence(bytes32 id) external view returns (Scoped.Evidence memory);
    function requireCurrent(StreamFinalityScope calldata scope)
        external
        view
        returns (Scoped.Evidence memory);
}
