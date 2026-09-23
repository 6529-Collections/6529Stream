// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredMultipleAttestationCodec as Codec
} from "./StreamArtistRecoveredMultipleAttestationCodec.sol";
import {
    StreamArtistRecoveredMultipleConsentValidation as Validation
} from "./StreamArtistRecoveredMultipleConsentValidation.sol";
import {
    StreamArtistRecoveredMultipleConsentBaseImport as Base
} from "./StreamArtistRecoveredMultipleConsentBaseImport.sol";
import {
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "./StreamArtistRecoveredContentConsentHydration.sol";
import {
    IStreamArtistEconomicsEvidence as Evidence
} from "../../interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";
import {
    StreamArtistSaleTypes as Sale
} from "../../interfaces/stream/artist/StreamArtistSaleTypes.sol";
import {
    IStreamArtistContentRecordsOwner as ContentOwner
} from "../../interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    StreamArtistContentTypes as Content
} from "../../interfaces/stream/artist/StreamArtistContentTypes.sol";

/// @notice Original content writes with each authenticated retained row's saved generation.
library StreamArtistRecoveredMultipleGenerationContentImport {
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
