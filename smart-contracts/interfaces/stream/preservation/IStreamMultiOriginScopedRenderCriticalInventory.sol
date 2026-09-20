// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistArchiveOriginTypes as O } from "./StreamArtistArchiveOriginTypes.sol";
import { IStreamArtistArchiveOriginInventory } from "./IStreamArtistArchiveOriginInventory.sol";

import { StreamFinalityScope } from "../finality/StreamArtworkFinalityTypes.sol";
import { StreamScopedRenderCriticalTypes as Scoped } from "./StreamScopedRenderCriticalTypes.sol";
import { StreamPreservationInventoryTypes as T } from "./StreamPreservationInventoryTypes.sol";
import { StreamRenderCriticalSourceTypes as S } from "./StreamRenderCriticalSourceTypes.sol";

import {
    IStreamStaticContentCheckpoint as Content
} from "../finality/IStreamStaticContentCheckpoint.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../metadata/IStreamScopedContentRootPublication.sol";
import { StreamWorkRecordTypes } from "../metadata/StreamWorkRecordTypes.sol";
import { StreamRightsRecordTypes } from "../metadata/StreamRightsRecordTypes.sol";
import { StreamConservationRecordTypes } from "../metadata/StreamConservationRecordTypes.sol";

/// @notice Additive scoped inventory with explicit historical receipt locators and a sealed origin table.
/// @dev A current completed inventory authenticates source closure, not archive coverage or finality.
interface IStreamMultiOriginScopedRenderCriticalInventory is IStreamArtistArchiveOriginInventory {
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
        address originalActor,
        O.ReceiptWitness calldata receipt
    ) external;
    function appendRights(bytes32 id, StreamRightsRecordTypes.Statement calldata witness) external;
    function appendIntent(
        bytes32 id,
        StreamConservationRecordTypes.Intent calldata witness,
        address originalActor,
        O.ReceiptWitness calldata receipt
    ) external;
    function appendIntentWaiver(
        bytes32 id,
        StreamConservationRecordTypes.IntentWaiver calldata witness,
        address originalActor,
        O.ReceiptWitness calldata receipt
    ) external;
    function appendInterview(
        bytes32 id,
        StreamConservationRecordTypes.Interview calldata witness,
        address originalActor,
        O.ReceiptWitness calldata receipt
    ) external;
    function appendInterviewWaiver(bytes32 id) external;
    function appendRootAuthorization(
        bytes32 id,
        address actor,
        uint64 observedAt,
        Root.Aggregate calldata originalAggregate,
        bytes32 originalLegacyFamilyHash,
        O.ReceiptWitness calldata receipt
    ) external;
    function appendOriginRuntime(bytes32 id) external;
    function originRuntimeCursor(bytes32 id) external view returns (uint256);
    function appendDefinition(bytes32 id) external;
    function appendTokenOutput(bytes32 id, Content.Payload calldata payload) external;
    function appendTokenScript(bytes32 id) external;
    function appendTokenLibrary(bytes32 id) external;
    function appendTokenRenderer(bytes32 id) external;
    function appendTokenCitation(bytes32 id) external;
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
