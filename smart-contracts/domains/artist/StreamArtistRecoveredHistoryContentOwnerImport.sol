// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
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
import { StreamArtistSanctionState as Sanctions } from "./StreamArtistSanctionState.sol";
import {
    StreamArtistRecoveredHistoryContentTypes as HC
} from "./StreamArtistRecoveredHistoryContentTypes.sol";
import {
    StreamArtistRecoveredHistoryContentImport as Import
} from "./StreamArtistRecoveredHistoryContentImport.sol";
import {
    StreamArtistRecoveredHistoryContentWrites as Writes
} from "./StreamArtistRecoveredHistoryContentWrites.sol";

/// @notice Single fixed new-profile entry over compiler-declared roots after the original host guard.
library StreamArtistRecoveredHistoryContentOwnerImport {
    function applyState(
        Sanctions.State storage sanctions,
        mapping(bytes32 => bytes32) storage policies,
        mapping(bytes32 => bytes32) storage economics,
        mapping(bytes32 => bytes32) storage associated,
        mapping(bytes32 => Evidence.Association) storage associations,
        mapping(bytes32 => bytes32) storage delegations,
        mapping(bytes32 => Sale.Record) storage sales,
        mapping(bytes32 => bytes32) storage latest,
        mapping(
            bytes32 => ContentOwner.ConsentRecord
        ) storage consents,
        mapping(bytes32 => bytes32) storage latestConsents,
        mapping(bytes32 => T.RoyaltyFreezeRecord) storage royalties,
        mapping(bytes32 => Content.FreezeRecord) storage freezes,
        mapping(bytes32 => bytes32) storage latestFreezes,
        mapping(uint256 => T.RatificationRecord) storage current,
        mapping(bytes32 => T.RatificationRecord) storage records,
        AH.Query memory q,
        bytes memory outer
    ) public {
        HC.Bundle memory b = Import.importState(
            sanctions,
            policies,
            economics,
            associated,
            associations,
            delegations,
            sales,
            latest,
            q,
            outer
        );
        Writes.importContent(
            consents, latestConsents, royalties, freezes, latestFreezes, delegations, HC.content(b)
        );
        Writes.importRecords(current, records, q.collectionId, b.ratifications);
    }
}
