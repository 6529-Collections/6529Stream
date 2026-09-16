// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../interfaces/stream/artist/IStreamArtistContentRatification.sol";
import "../../interfaces/stream/artist/IStreamArtistContentAuthority.sol";

/// @notice Fixed-library consent consumption and ratification continuity in Router storage.
library StreamMetadataContentAuthorization {
    struct Context {
        address core;
        address artist;
        uint256 collectionId;
        bytes32 currentState;
    }

    error ArtistContentEvolutionBroken(uint256 collectionId);
    error ArtistContentAuthorizationRequired(uint256 collectionId);
    error ArtistContentConsentConsumed(bytes32 recordHash);

    event ArtistContentConsentApplied(
        uint256 indexed collectionId,
        bytes32 indexed familyId,
        bytes32 indexed consentRecordHash,
        bytes32 resultingContentStateHash,
        uint16 schemaVersion
    );

    function authorize(
        mapping(bytes32 => bool) storage consumed,
        mapping(uint256 => bytes32) storage evolutionRatification,
        mapping(uint256 => bytes32) storage evolutionContent,
        Context memory ctx,
        bytes32 familyId,
        bytes32 newStateHash
    ) public returns (bytes32 consent, bytes32 ratification) {
        (bool ratified, bytes32 ratifiedState, bytes32 record) =
            IStreamArtistContentRatification(ctx.artist).firstReleaseRatification(ctx.collectionId);
        if (!ratified) {
            if (
                IStreamCoreCollectionView(ctx.core).collectionMintedEver(ctx.collectionId) == 0
                    || IStreamArtistAttribution(ctx.artist)
                        .attribution(ctx.collectionId)
                        .nominatedArtist == address(0)
            ) return (0, 0);
        } else {
            if (
                record == bytes32(0)
                    || (ctx.currentState != ratifiedState
                        && (evolutionRatification[ctx.collectionId] != record
                            || evolutionContent[ctx.collectionId] != ctx.currentState))
            ) revert ArtistContentEvolutionBroken(ctx.collectionId);
            ratification = record;
        }
        try IStreamArtistContentAuthority(ctx.artist)
            .contentConsentEvidence(ctx.collectionId, familyId, newStateHash) returns (
            bytes32 evidence
        ) {
            consent = evidence;
        } catch {
            revert ArtistContentAuthorizationRequired(ctx.collectionId);
        }
        if (consent == bytes32(0)) revert ArtistContentAuthorizationRequired(ctx.collectionId);
        if (consumed[consent]) revert ArtistContentConsentConsumed(consent);
        consumed[consent] = true;
    }

    function recordApplication(
        mapping(uint256 => bytes32) storage evolutionRatification,
        mapping(uint256 => bytes32) storage evolutionContent,
        uint256 collectionId,
        bytes32 familyId,
        bytes32 consent,
        bytes32 ratification,
        bytes32 currentState
    ) public {
        if (consent == bytes32(0)) return;
        if (ratification != bytes32(0)) {
            evolutionRatification[collectionId] = ratification;
            evolutionContent[collectionId] = currentState;
        }
        emit ArtistContentConsentApplied(collectionId, familyId, consent, currentState, 1);
    }
}
