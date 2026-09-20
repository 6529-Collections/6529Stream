// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import {
    StreamArtistRecoveredIdentityHydrationState as X
} from "./StreamArtistRecoveredIdentityHydrationState.sol";

import {
    StreamArtistIdentityRecoveryReceipts as Receipts
} from "./StreamArtistIdentityRecoveryReceipts.sol";

/// @notice Fixed Identity export stage in the original owner storage context.
library StreamArtistRecoveredIdentityExportRecordRowsB {
    function row31(uint256[17] memory r, bytes32 artistId, RH.JournalEntry memory j, uint16 op)
        public
        view
        returns (bool cause, bytes memory encoded)
    {
        bytes32 key = j.receipt.recordHash;
        if (X.resolutions(r).causes[key].causeHash != 0) {
            return (
                true,
                abi.encode(
                    IH.CauseRow(
                        j.position.point,
                        X.resolutions(r).causes[key],
                        X.dormancy(r).causeNotice[key]
                    )
                )
            );
        } else if (op == 33) {
            return (false, abi.encode(IH.ContestRow(j.position, X.contests(r).records[key])));
        } else {
            revert IH.InvalidRecoveredIdentity(key);
        }
    }

    function row35(uint256[17] memory r, bytes32 artistId, RH.JournalEntry memory j)
        public
        view
        returns (bytes memory)
    {
        bytes32 key = j.receipt.recordHash;
        if (X.recovery(r).records[key].recordHash == 0) return bytes("");
        IH.RecoveryRow memory row;
        row.position = j.position;
        row.record = X.recovery(r).records[key];
        row.transition = X.recovery(r).transitions[key];
        row.guardian = X.recovery(r).recoveryGuardians[key];
        row.primaryReceipt = X.recovery(r).receipts.receipts[Receipts.PRIMARY][key];
        row.secondaryOccurrence =
            Receipts.occurrenceKey(key, row.record.fields.supersededRecordsHash);
        row.secondaryReceipt = X.recovery(r).receipts.secondaryOccurrences[row.secondaryOccurrence];
        return abi.encode(row);
    }

    function row51(uint256[17] memory r, bytes32 artistId, RH.JournalEntry memory j)
        public
        view
        returns (bytes memory)
    {
        bytes32 key = j.receipt.recordHash;
        return abi.encode(
            IH.StandingRecordRow(
                j.position,
                X.rotations(r).standingRecords[key],
                X.rewinds(r).statuses[key],
                X.rewinds(r).standingRecordContinuations[key]
            )
        );
    }

    function row58(uint256[17] memory r, bytes32 artistId, RH.JournalEntry memory j)
        public
        view
        returns (bytes memory)
    {
        bytes32 key = j.receipt.recordHash;
        return abi.encode(IH.DismissalRow(j.position, X.resolutions(r).records[key]));
    }
}
