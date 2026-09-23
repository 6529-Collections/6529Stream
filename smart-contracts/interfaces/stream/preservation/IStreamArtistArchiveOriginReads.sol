// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistArchiveOriginTypes as O } from "./StreamArtistArchiveOriginTypes.sol";
import { StreamRenderCriticalSourceTypes as S } from "./StreamRenderCriticalSourceTypes.sol";
import { StreamPreservationInventoryTypes as T } from "./StreamPreservationInventoryTypes.sol";
import {
    StreamArtistRecordPublicationTypes as P
} from "../artist/StreamArtistRecordPublicationTypes.sol";
import "../metadata/IStreamMetadataServingFacts.sol";
import "../metadata/IStreamConservationRecordSelection.sol";

import { StreamScopedRenderCriticalTypes as Scoped } from "./StreamScopedRenderCriticalTypes.sol";
import {
    StreamPolicyRenderCriticalTypesV2 as Policy
} from "./StreamPolicyRenderCriticalTypesV2.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as ScopedPolicy
} from "./StreamScopedPolicyRenderCriticalTypesV2.sol";
import "../metadata/IStreamScopedContentRootPublication.sol";

/// @notice Fixed typed original-producer proof. A return confers no authority outside its
/// authenticated inventory context. Content origin is completed by the exact root codec.
interface IStreamArtistArchiveOriginReads {
    function currentOrigin(S.Dependencies calldata d)
        external
        view
        returns (O.Origin memory current, bytes32 completion);

    function lineage(
        S.Dependencies calldata d,
        uint256 collectionId,
        IStreamMetadataServingFacts.ArtistPresentation calldata presented,
        IStreamConservationRecordSelection.Association calldata association
    ) external view returns (O.Origin memory current, O.Origin memory original, bytes32 lineageHash);

    function publicationItem(
        S.Dependencies calldata d,
        P.Evidence calldata expected,
        bytes32 originalRecord,
        address actor,
        bytes32 sourceContextHash,
        O.ReceiptWitness calldata witness
    ) external view returns (T.Item memory item, O.RecordOrigin memory original);

    function contentOrigin(
        S.Dependencies calldata d,
        uint256 collectionId,
        bytes32 artistId,
        bytes32 consentRecord,
        address actor,
        O.ContentRole role,
        bytes32 sourceContextHash,
        O.ReceiptWitness calldata witness
    ) external view returns (O.RecordOrigin memory original);

    function contentItem(
        S.Dependencies calldata d,
        S.Context calldata context,
        address actor,
        uint64 originalObservedAt,
        bytes32 sourceContextHash,
        O.ReceiptWitness calldata witness
    ) external view returns (T.Item memory item, O.RecordOrigin memory original);

    function scopedContentItem(
        S.Dependencies calldata d,
        Scoped.Context calldata context,
        address actor,
        uint64 originalObservedAt,
        IStreamScopedContentRootPublication.Aggregate calldata originalAggregate,
        bytes32 originalLegacyFamilyHash,
        bytes32 sourceContextHash,
        O.ReceiptWitness calldata witness
    ) external view returns (T.Item memory item, O.RecordOrigin memory original);

    function policyContentItem(
        S.Dependencies calldata d,
        Policy.Context calldata context,
        address actor,
        uint64 originalObservedAt,
        IStreamScopedContentRootPublication.Aggregate calldata originalAggregate,
        bytes32 sourceContextHash,
        O.ReceiptWitness calldata witness
    ) external view returns (T.Item memory item, O.RecordOrigin memory original);

    function scopedPolicyContentItem(
        S.Dependencies calldata d,
        ScopedPolicy.Context calldata context,
        address actor,
        uint64 originalObservedAt,
        IStreamScopedContentRootPublication.Aggregate calldata originalAggregate,
        bytes32 originalLegacyFamilyHash,
        bytes32 sourceContextHash,
        O.ReceiptWitness calldata witness
    ) external view returns (T.Item memory item, O.RecordOrigin memory original);
}
