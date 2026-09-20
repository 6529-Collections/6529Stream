// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import {
    StreamArtistRecoveredIdentityExportEncoding as Encoding
} from "./StreamArtistRecoveredIdentityExportEncoding.sol";
import {
    StreamArtistRecoveredIdentityExportRecordRowsA as RowsA
} from "./StreamArtistRecoveredIdentityExportRecordRowsA.sol";
import {
    StreamArtistRecoveredIdentityExportRecordRowsB as RowsB
} from "./StreamArtistRecoveredIdentityExportRecordRowsB.sol";
import {
    StreamArtistRecoveredIdentityExportRecordRowsC as RowsC
} from "./StreamArtistRecoveredIdentityExportRecordRowsC.sol";
import {
    StreamArtistRecoveredIdentityExportRecordRowsD as RowsD
} from "./StreamArtistRecoveredIdentityExportRecordRowsD.sol";

/// @notice Fixed Identity export stage in the original owner storage context.
library StreamArtistRecoveredIdentityExportRecords {
    function collect(uint256[17] memory r, bytes32 artistId, RH.OwnerProvenance memory p)
        public
        view
        returns (bytes[15] memory fields)
    {
        uint256[62] memory n;
        for (uint256 i; i < p.journal.length; ++i) {
            if (p.journal[i].receipt.artistId == artistId) ++n[p.journal[i].receipt.operation];
        }
        bytes[][62] memory rows;
        rows[25] = new bytes[](n[25]);
        rows[26] = new bytes[](n[26]);
        rows[28] = new bytes[](n[28]);
        rows[29] = new bytes[](n[29]);
        rows[33] = new bytes[](n[33] / 2);
        rows[31] = new bytes[](n[33] / 2 + n[31]);
        rows[58] = new bytes[](n[58]);
        rows[51] = new bytes[](n[51]);
        rows[35] = new bytes[](n[35] / 2);
        rows[36] = new bytes[](n[36]);
        rows[37] = new bytes[](n[37]);
        rows[19] = new bytes[](n[19]);
        rows[38] = new bytes[](n[38]);
        rows[41] = new bytes[](n[41]);
        rows[23] = new bytes[](n[23]);
        uint256[62] memory at;
        uint256 causeAt;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory j = p.journal[i];
            if (j.receipt.artistId != artistId) continue;
            uint16 op = j.receipt.operation;
            if (op == 25) {
                bytes memory row = RowsA.row25(r, artistId, j);
                rows[op][at[op]++] = row;
            } else if (op == 26) {
                bytes memory row = RowsA.row26(r, artistId, j);
                rows[op][at[op]++] = row;
            } else if (op == 28) {
                bytes memory row = RowsA.row28(r, artistId, j);
                rows[op][at[op]++] = row;
            } else if (op == 29) {
                bytes memory row = RowsA.row29(r, artistId, j);
                rows[op][at[op]++] = row;
            } else if (op == 31 || op == 33) {
                (bool cause, bytes memory row) = RowsB.row31(r, artistId, j, op);
                if (cause) rows[31][causeAt++] = row;
                else rows[33][at[op]++] = row;
            } else if (op == 35) {
                bytes memory row = RowsB.row35(r, artistId, j);
                if (row.length == 0) continue;
                rows[op][at[op]++] = row;
            } else if (op == 36) {
                bytes memory row = RowsC.row36(r, artistId, j);
                rows[op][at[op]++] = row;
            } else if (op == 37) {
                bytes memory row = RowsC.row37(r, artistId, j);
                rows[op][at[op]++] = row;
            } else if (op == 19) {
                bytes memory row = RowsC.row19(r, artistId, j);
                rows[op][at[op]++] = row;
            } else if (op == 38) {
                bytes memory row = RowsC.row38(r, artistId, j);
                rows[op][at[op]++] = row;
            } else if (op == 41) {
                bytes memory row = RowsC.row41(r, artistId, j);
                rows[op][at[op]++] = row;
            } else if (op == 51) {
                bytes memory row = RowsB.row51(r, artistId, j);
                rows[op][at[op]++] = row;
            } else if (op == 58) {
                bytes memory row = RowsB.row58(r, artistId, j);
                rows[op][at[op]++] = row;
            } else if (op == 23) {
                bytes memory row = RowsD.row23(r, artistId, j);
                rows[op][at[op]++] = row;
            }
        }
        if (causeAt != rows[31].length || at[33] != rows[33].length || at[35] != rows[35].length) {
            revert IH.InvalidRecoveredIdentity(artistId);
        }
        fields[0] = Encoding.array(rows[25], true);
        fields[1] = Encoding.array(rows[26], false);
        fields[2] = Encoding.array(rows[28], true);
        fields[3] = Encoding.array(rows[29], true);
        fields[4] = Encoding.array(rows[33], false);
        fields[5] = Encoding.array(rows[31], false);
        fields[6] = Encoding.array(rows[58], false);
        fields[7] = Encoding.array(rows[51], false);
        fields[8] = Encoding.array(rows[35], true);
        fields[9] = Encoding.array(rows[36], false);
        fields[10] = Encoding.array(rows[37], true);
        fields[11] = Encoding.array(rows[19], false);
        fields[12] = Encoding.array(rows[38], true);
        fields[13] = Encoding.array(rows[41], true);
        fields[14] = Encoding.array(rows[23], true);
    }
}
