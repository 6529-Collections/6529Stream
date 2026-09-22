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
    StreamArtistRecoveredMultipleGenerationCodec as Codec
} from "./StreamArtistRecoveredMultipleGenerationCodec.sol";
import {
    StreamArtistRecoveredMultipleGenerationConsentValidation as Validation
} from "./StreamArtistRecoveredMultipleGenerationConsentValidation.sol";
import {
    StreamArtistRecoveredMultipleGenerationConsentBaseImport as Base
} from "./StreamArtistRecoveredMultipleGenerationConsentBaseImport.sol";
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

import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationContentImport as ContentImport
} from "./StreamArtistRecoveredMultipleGenerationContentImport.sol";

/// @notice One whole-owner validation and original empty-key installation of all Consent collections.
library StreamArtistRecoveredMultipleGenerationConsentImport {
    function applyState(
        mapping(bytes32 => bytes32) storage policies,
        mapping(bytes32 => bytes32) storage economics,
        mapping(bytes32 => bytes32) storage associated,
        mapping(bytes32 => Evidence.Association) storage associations,
        mapping(bytes32 => bytes32) storage delegations,
        mapping(bytes32 => Sale.Record) storage sales,
        mapping(bytes32 => bytes32) storage latest,
        mapping(
            bytes32 => ContentOwner.ConsentRecord
        ) storage content,
        mapping(bytes32 => bytes32) storage latestContent,
        mapping(bytes32 => T.RoyaltyFreezeRecord) storage royalties,
        mapping(bytes32 => Content.FreezeRecord) storage freezes,
        mapping(bytes32 => bytes32) storage latestFreezes,
        AH.Query memory anchor,
        bytes memory outer
    ) public returns (bool) {
        if (!Codec.selected(outer, 6)) return false;
        (M.State memory s, Payload.Payload memory p) = Codec.outer(6, anchor, outer);
        G.Consents[] memory all = new G.Consents[](s.rows.length);
        for (uint256 i; i < all.length; ++i) {
            all[i] = abi.decode(s.rows[i], (G.Consents));
            if (keccak256(s.rows[i]) != keccak256(abi.encode(all[i]))) {
                revert RH.InvalidRecoveredHydrationProfile();
            }
        }
        Validation.validate(all, s.collections, p.provenance);
        for (uint256 i; i < all.length; ++i) {
            Base.install(
                policies,
                economics,
                associated,
                associations,
                delegations,
                sales,
                latest,
                s.collections[i],
                all[i].rows.original
            );
            ContentImport.importContent(
                content, latestContent, royalties, freezes, latestFreezes, delegations, all[i].rows
            );
        }
        return true;
    }
}
