// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistCompleteHistoryCodec as Codec } from "./StreamArtistCompleteHistoryCodec.sol";
import {
    StreamArtistCompleteHistoryConsentProof as Proof
} from "./StreamArtistCompleteHistoryConsentProof.sol";
import {
    StreamArtistCompleteHistoryConsentWrites as Writes
} from "./StreamArtistCompleteHistoryConsentWrites.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
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

/// @notice Original owner6 base/content maps, with all collection targets checked before writes.
/// @dev Reached only beneath the fixed original op60 guard after whole seven-owner proof.
/// The existing three-map supplemental hook is mandatory in that same atomic operation.
library StreamArtistCompleteHistoryConsentImport {
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
        Proof.Result memory r = Proof.collect(anchor, outer);
        for (uint256 k; k < r.original.length; ++k) {
            Writes.checkBase(
                policies,
                economics,
                associated,
                associations,
                delegations,
                sales,
                latest,
                r.scope.collections[k],
                r.original[k].rows.original
            );
            Writes.checkContent(
                content,
                latestContent,
                royalties,
                freezes,
                latestFreezes,
                delegations,
                r.original[k].rows
            );
        }
        for (uint256 k; k < r.original.length; ++k) {
            Writes.installBase(
                policies,
                economics,
                associated,
                associations,
                delegations,
                sales,
                latest,
                r.scope.collections[k],
                r.original[k].rows.original
            );
            Writes.installContent(
                content,
                latestContent,
                royalties,
                freezes,
                latestFreezes,
                delegations,
                r.original[k].rows
            );
        }
        return true;
    }
}
