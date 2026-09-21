// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistAttributionOwner as Attr
} from "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    IStreamArtistAttributionDisputesOwner as Disputes,
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    IStreamArtistEconomicsEvidence as Economics
} from "../../interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";
import {
    IStreamArtistSaleConsentOwner as Sales
} from "../../interfaces/stream/artist/IStreamArtistSaleOwner.sol";

/// @notice Choose the additional history codec only outside the supported historical profiles.
library StreamArtistRecoveredDisputeSelection {
    function selected(T.SuiteConfiguration memory source, AH.Query memory q, RH.Provenance memory p)
        public
        view
        returns (bool)
    {
        bool any;
        for (uint256 i; i < p.journals[4].length; ++i) {
            uint16 op = p.journals[4][i].receipt.operation;
            if (op == 45 || op == 47 || op == 61) return true;
            if (op != 44) continue;
            any = true;
            AD.Record memory row = Disputes(source.owners[4])
                .attributionDisputeRecord(p.journals[4][i].receipt.recordHash);
            if (row.governanceActionId == 0 || row.previousRecordHash != 0) return true;
            AD.Head memory h = Disputes(source.owners[4])
                .attributionDispute(q.collectionId, row.terms.bindingGeneration);
            if (
                h.open || h.reopened || h.revocationReason != 4 || h.counterStatementRecordHash != 0
            ) return true;
        }
        if (!any) return false;
        if (p.journals[3].length < 2 || p.journals[4].length != p.journals[3].length - 1) {
            return true;
        }
        (uint8 state,) = Attr(source.owners[4]).attributionState(q.collectionId);
        if (state != 2) return true;
        for (uint256 i; i < p.journals[6].length; ++i) {
            RH.JournalEntry memory entry = p.journals[6][i];
            if (
                entry.receipt.operation == 15
                    && Economics(source.owners[6])
                        .economicsRecordAssociation(entry.receipt.recordHash)
                        .bindingHash != q.bindingHash
            ) return true;
            if (
                entry.receipt.operation == 16
                    && Sales(source.owners[6])
                        .saleConsentRecord(entry.receipt.recordHash)
                        .bindingHash != q.bindingHash
            ) return true;
        }
        return false;
    }
}
