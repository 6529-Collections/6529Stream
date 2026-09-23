// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC165 } from "../../../vendor/openzeppelin/IERC165.sol";
import {
    IStreamPreservationPolicyRenderCriticalInventoryV1
} from "./IStreamPreservationPolicyRenderCriticalInventoryV1.sol";
import { IStreamArtistArchiveOriginInventory } from "./IStreamArtistArchiveOriginInventory.sol";
import { IStreamCurrentAuthorityInventory } from "./IStreamCurrentAuthorityInventory.sol";
import { StreamArtistArchiveOriginTypes as O } from "./StreamArtistArchiveOriginTypes.sol";
import { StreamPreservationInventoryTypes as T } from "./StreamPreservationInventoryTypes.sol";
import { StreamWorkRecordTypes } from "../metadata/StreamWorkRecordTypes.sol";
import { StreamRightsRecordTypes } from "../metadata/StreamRightsRecordTypes.sol";
import { StreamConservationRecordTypes } from "../metadata/StreamConservationRecordTypes.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Content
} from "../finality/IStreamPreservationPolicyContentCheckpointV1.sol";

/// @notice Complete witness-aware COLLECTION preservation inventory; no legacy writer overloads.
/// @dev Six token stages and every admitted original runtime precede the origin-bound seal.
interface IStreamCurrentAuthorityPreservationPolicyRenderCriticalInventoryV1 is
    IERC165,
    IStreamPreservationPolicyRenderCriticalInventoryV1,
    IStreamArtistArchiveOriginInventory,
    IStreamCurrentAuthorityInventory
{
    function beginInventory(uint256 collectionId) external returns (bytes32);
    function appendNative(bytes32 id) external;
    function appendReference(bytes32 id) external;
    function appendWork(
        bytes32 id,
        StreamWorkRecordTypes.Description calldata value,
        address actor,
        O.ReceiptWitness calldata witness
    ) external;
    function appendRights(bytes32 id, StreamRightsRecordTypes.Statement calldata value) external;
    function appendIntent(
        bytes32 id,
        StreamConservationRecordTypes.Intent calldata value,
        address actor,
        O.ReceiptWitness calldata witness
    ) external;
    function appendIntentWaiver(
        bytes32 id,
        StreamConservationRecordTypes.IntentWaiver calldata value,
        address actor,
        O.ReceiptWitness calldata witness
    ) external;
    function appendInterview(
        bytes32 id,
        StreamConservationRecordTypes.Interview calldata value,
        address actor,
        O.ReceiptWitness calldata witness
    ) external;
    function appendInterviewWaiver(bytes32 id) external;
    function appendRootAuthorization(
        bytes32 id,
        address actor,
        uint64 observedAt,
        Root.Aggregate calldata originalAggregate,
        O.ReceiptWitness calldata witness
    ) external;
    function appendDefinition(bytes32 id) external;
    function appendToken(bytes32 id, Content.Payload calldata payload) external;
    function appendScript(bytes32 id) external;
    function appendLibrary(bytes32 id) external;
    function appendRenderer(bytes32 id) external;
    function appendCurrentProfile(bytes32 id) external;
    function appendOriginRuntime(bytes32 id) external;
    function sealInventory(bytes32 id) external returns (T.Evidence memory);
    function requireFullDefinitionBytes(bytes32 id) external view;
}
