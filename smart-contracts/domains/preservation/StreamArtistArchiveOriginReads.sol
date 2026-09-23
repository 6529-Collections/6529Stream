// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamArtistRecordPublicationTypes as P
} from "../../interfaces/stream/artist/StreamArtistRecordPublicationTypes.sol";
import "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import { StreamArtistArchiveOriginProof as Proof } from "./StreamArtistArchiveOriginProof.sol";
import {
    StreamArtistArchiveOriginLineage as Lineage
} from "./StreamArtistArchiveOriginLineage.sol";
import {
    StreamMultiOriginArtistBundleReads as Bundles
} from "./StreamMultiOriginArtistBundleReads.sol";

import {
    StreamScopedRenderCriticalTypes as Scoped
} from "../../interfaces/stream/preservation/StreamScopedRenderCriticalTypes.sol";
import {
    StreamPolicyRenderCriticalTypesV2 as Policy
} from "../../interfaces/stream/preservation/StreamPolicyRenderCriticalTypesV2.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as ScopedPolicy
} from "../../interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
import "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    StreamMultiOriginScopedRootAuthorization as ScopedRoots
} from "./StreamMultiOriginScopedRootAuthorization.sol";
import {
    StreamMultiOriginPolicyRootAuthorizationV2 as PolicyRoots
} from "./StreamMultiOriginPolicyRootAuthorizationV2.sol";
import {
    StreamMultiOriginScopedPolicyRootAuthorizationV2 as ScopedPolicyRoots
} from "./StreamMultiOriginScopedPolicyRootAuthorizationV2.sol";
import {
    IStreamArtistArchiveOriginReads
} from "../../interfaces/stream/preservation/IStreamArtistArchiveOriginReads.sol";

/// @notice Constructor-pinned, typed read worker for the additive preservation profile.
/// @dev Callers provide one finite STATICCALL frame. Public results alone grant no authority.
contract StreamArtistArchiveOriginReads is IStreamArtistArchiveOriginReads {
    function currentOrigin(S.Dependencies memory d)
        public
        view
        returns (O.Origin memory current, bytes32 completion)
    {
        return Proof.currentOrigin(d);
    }

    function lineage(
        S.Dependencies memory d,
        uint256 collectionId,
        IStreamMetadataServingFacts.ArtistPresentation memory presented,
        IStreamConservationRecordSelection.Association memory association
    ) public view returns (O.Origin memory current, O.Origin memory original, bytes32 lineageHash) {
        return Lineage.lineage(d, collectionId, presented, association);
    }

    function publicationItem(
        S.Dependencies memory d,
        P.Evidence memory expected,
        bytes32 originalRecord,
        address actor,
        bytes32 sourceContextHash,
        O.ReceiptWitness memory witness
    ) public view returns (T.Item memory item, O.RecordOrigin memory original) {
        return
            Bundles.publicationItem(d, expected, originalRecord, actor, sourceContextHash, witness);
    }

    function contentOrigin(
        S.Dependencies memory d,
        uint256 collectionId,
        bytes32 artistId,
        bytes32 consentRecord,
        address actor,
        O.ContentRole role,
        bytes32 sourceContextHash,
        O.ReceiptWitness memory witness
    ) public view returns (O.RecordOrigin memory original) {
        return Proof.contentOrigin(
            d, collectionId, artistId, consentRecord, actor, role, sourceContextHash, witness
        );
    }

    function contentItem(
        S.Dependencies memory d,
        S.Context memory context,
        address actor,
        uint64 originalObservedAt,
        bytes32 sourceContextHash,
        O.ReceiptWitness memory witness
    ) public view returns (T.Item memory item, O.RecordOrigin memory original) {
        return
            Bundles.contentItem(d, context, actor, originalObservedAt, sourceContextHash, witness);
    }

    function scopedContentItem(
        S.Dependencies memory d,
        Scoped.Context memory context,
        address actor,
        uint64 originalObservedAt,
        IStreamScopedContentRootPublication.Aggregate memory originalAggregate,
        bytes32 originalLegacyFamilyHash,
        bytes32 sourceContextHash,
        O.ReceiptWitness memory witness
    ) public view returns (T.Item memory item, O.RecordOrigin memory original) {
        return ScopedRoots.contentItem(
            d,
            context,
            actor,
            originalObservedAt,
            originalAggregate,
            originalLegacyFamilyHash,
            sourceContextHash,
            witness
        );
    }

    function policyContentItem(
        S.Dependencies memory d,
        Policy.Context memory context,
        address actor,
        uint64 originalObservedAt,
        IStreamScopedContentRootPublication.Aggregate memory originalAggregate,
        bytes32 sourceContextHash,
        O.ReceiptWitness memory witness
    ) public view returns (T.Item memory item, O.RecordOrigin memory original) {
        return PolicyRoots.contentItem(
            d, context, actor, originalObservedAt, originalAggregate, sourceContextHash, witness
        );
    }

    function scopedPolicyContentItem(
        S.Dependencies memory d,
        ScopedPolicy.Context memory context,
        address actor,
        uint64 originalObservedAt,
        IStreamScopedContentRootPublication.Aggregate memory originalAggregate,
        bytes32 originalLegacyFamilyHash,
        bytes32 sourceContextHash,
        O.ReceiptWitness memory witness
    ) public view returns (T.Item memory item, O.RecordOrigin memory original) {
        return ScopedPolicyRoots.contentItem(
            d,
            context,
            actor,
            originalObservedAt,
            originalAggregate,
            originalLegacyFamilyHash,
            sourceContextHash,
            witness
        );
    }
}
