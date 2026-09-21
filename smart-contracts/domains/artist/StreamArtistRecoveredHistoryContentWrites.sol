// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredDisputeConsentHistory as DisputeHistory
} from "./StreamArtistRecoveredDisputeConsentHistory.sol";

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistDelegationHydrationTypes as DH
} from "../../interfaces/stream/artist/IStreamArtistDelegationAuthorityHydration.sol";
import {
    StreamArtistEconomicsHydrationTypes as EH
} from "../../interfaces/stream/artist/IStreamArtistEconomicsAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistSaleTypes as Sale
} from "../../interfaces/stream/artist/StreamArtistSaleTypes.sol";

import {
    IStreamArtistEconomicsEvidence as Evidence
} from "../../interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";

import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistEconomicsAssociation as Association
} from "./StreamArtistEconomicsAssociation.sol";
import { StreamArtistSaleHashes } from "./StreamArtistSaleHashes.sol";

import {
    StreamArtistRecoveredDelegatedConsentHydration as Base
} from "./StreamArtistRecoveredDelegatedConsentHydration.sol";
import {
    StreamArtistContentTypes as Content
} from "../../interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    IStreamArtistContentRecordsOwner as ContentOwner
} from "../../interfaces/stream/artist/IStreamArtistContentOwner.sol";

import {
    StreamArtistRecoveredContentConsentReads as Reads
} from "./StreamArtistRecoveredContentConsentReads.sol";
import {
    StreamArtistRecoveredContentConsentValidation as Validation
} from "./StreamArtistRecoveredContentConsentValidation.sol";

import {
    StreamArtistRecoveredGenerationConsents as Generation
} from "./StreamArtistRecoveredGenerationConsents.sol";

import {
    StreamArtistRecoveredGenerationBaseConsents as GenerationBase
} from "./StreamArtistRecoveredGenerationBaseConsents.sol";

import {
    StreamArtistRecoveredGenerationDelegatedConsents as GenerationDelegated
} from "./StreamArtistRecoveredGenerationDelegatedConsents.sol";

import {
    StreamArtistRecoveredRatificationHydration as Ratified
} from "./StreamArtistRecoveredRatificationHydration.sol";

import {
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "./StreamArtistRecoveredContentConsentHydration.sol";

/// @notice Original typed content maps use each authenticated historical generation, never the current one.
library StreamArtistRecoveredHistoryContentWrites {
    function importContent(
        mapping(bytes32 => ContentOwner.ConsentRecord) storage consents,
        mapping(bytes32 => bytes32) storage latestConsents,
        mapping(bytes32 => T.RoyaltyFreezeRecord) storage royalties,
        mapping(bytes32 => Content.FreezeRecord) storage freezes,
        mapping(bytes32 => bytes32) storage latestFreezes,
        mapping(bytes32 => bytes32) storage delegations,
        ContentH.Bundle memory b
    ) public {
        // The new base-only decoder has authenticated every row and requires all three empty.
        // That profile owns no content/freeze head, so the second atomic import half has no writes.
        if (b.consents.length == 0 && b.royalties.length == 0 && b.freezes.length == 0) return;
        ContentOwner.ConsentRecord memory emptyConsent;
        T.RoyaltyFreezeRecord memory emptyRoyalty;
        Content.FreezeRecord memory emptyFreeze;
        // Precheck every shared head before writing: repeated exact17 terms and overlapping21
        // lock sets are genuine producer histories, not duplicate inventory errors.
        for (uint256 i; i < b.consents.length; ++i) {
            ContentOwner.ConsentRecord memory r = b.consents[i];
            if (
                keccak256(abi.encode(consents[r.recordHash])) != keccak256(abi.encode(emptyConsent))
                    || latestConsents[_contentScope(r.terms, r.bindingGeneration)] != 0
                    || delegations[r.recordHash] != 0
            ) _invalid();
        }
        for (uint256 i; i < b.royalties.length; ++i) {
            ContentH.Royalty memory r = b.royalties[i];
            if (
                keccak256(
                            abi.encode(
                                royalties[_royaltyScope(
                                        r.terms, b.original.artistId, r.item.bindingGeneration
                                    )]
                            )
                        ) != keccak256(abi.encode(emptyRoyalty))
                    || delegations[r.item.recordHash] != 0
            ) _invalid();
        }
        for (uint256 i; i < b.freezes.length; ++i) {
            Content.FreezeRecord memory r = b.freezes[i];
            if (
                keccak256(abi.encode(freezes[r.recordHash])) != keccak256(abi.encode(emptyFreeze))
                    || delegations[r.recordHash] != 0
            ) _invalid();
            for (uint256 j; j < r.lockClasses.length; ++j) {
                if (
                    latestFreezes[
                            _freezeLookup(
                                b.original.collectionId,
                                r.bindingGeneration,
                                r.metadataContract,
                                r.lockClasses[j]
                            )
                        ] != 0
                ) _invalid();
            }
        }
        for (uint256 i; i < b.consents.length; ++i) {
            ContentOwner.ConsentRecord memory r = b.consents[i];
            consents[r.recordHash] = r;
            latestConsents[_contentScope(r.terms, r.bindingGeneration)] = r.recordHash;
        }
        for (uint256 i; i < b.royalties.length; ++i) {
            ContentH.Royalty memory r = b.royalties[i];
            royalties[_royaltyScope(r.terms, b.original.artistId, r.item.bindingGeneration)] =
            r.item;
            delegations[r.item.recordHash] = r.grant;
        }
        for (uint256 i; i < b.freezes.length; ++i) {
            Content.FreezeRecord memory r = b.freezes[i];
            freezes[r.recordHash] = r;
            for (uint256 j; j < r.lockClasses.length; ++j) {
                latestFreezes[
                    _freezeLookup(
                        b.original.collectionId,
                        r.bindingGeneration,
                        r.metadataContract,
                        r.lockClasses[j]
                    )
                ] = r.recordHash;
            }
        }
    }

    function importRecords(
        mapping(uint256 => T.RatificationRecord) storage current,
        mapping(bytes32 => T.RatificationRecord) storage records,
        uint256 collectionId,
        T.RatificationRecord[] memory ratifications
    ) public {
        T.RatificationRecord memory empty;
        if (keccak256(abi.encode(current[collectionId])) != keccak256(abi.encode(empty))) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        for (uint256 i; i < ratifications.length; ++i) {
            if (
                keccak256(abi.encode(records[ratifications[i].recordHash]))
                    != keccak256(abi.encode(empty))
            ) revert RH.InvalidRecoveredHydrationProfile();
        }
        for (uint256 i; i < ratifications.length; ++i) {
            T.RatificationRecord memory r = ratifications[i];
            records[r.recordHash] = r;
            current[collectionId] = r;
        }
    }

    function _contentScope(Content.Consent memory terms, uint64 generation)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(terms, generation));
    }

    function _royaltyScope(T.RoyaltyFreeze memory terms, bytes32 artist, uint64 generation)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(terms, artist, generation));
    }

    function _freezeLookup(
        uint256 collection,
        uint64 generation,
        address metadata,
        bytes32 lockClass
    ) private pure returns (bytes32) {
        return keccak256(abi.encode(collection, generation, metadata, lockClass));
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
