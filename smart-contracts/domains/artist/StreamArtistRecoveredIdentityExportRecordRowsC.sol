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

/// @notice Fixed Identity export stage in the original owner storage context.
library StreamArtistRecoveredIdentityExportRecordRowsC {
    function row36(uint256[17] memory r, bytes32 artistId, RH.JournalEntry memory j)
        public
        view
        returns (bytes memory)
    {
        bytes32 key = j.receipt.recordHash;
        return abi.encode(
            IH.DesignationRow(
                j.position, X.succession(r).designations[key], X.rewinds(r).statuses[key]
            )
        );
    }

    function row37(uint256[17] memory r, bytes32 artistId, RH.JournalEntry memory j)
        public
        view
        returns (bytes memory)
    {
        bytes32 key = j.receipt.recordHash;
        return abi.encode(
            IH.DirectiveRow(
                j.position,
                X.succession(r).directives[key],
                X.succession(r).payloads[key],
                X.rewinds(r).statuses[key]
            )
        );
    }

    function row19(uint256[17] memory r, bytes32 artistId, RH.JournalEntry memory j)
        public
        view
        returns (bytes memory)
    {
        bytes32 key = j.receipt.recordHash;
        return abi.encode(
            IH.GrantRow(j.position, X.sanctions(r).records[key], X.rewinds(r).statuses[key])
        );
    }

    function row38(uint256[17] memory r, bytes32 artistId, RH.JournalEntry memory j)
        public
        view
        returns (bytes memory)
    {
        bytes32 key = j.receipt.recordHash;
        return abi.encode(
            IH.EstateRow(
                j.position,
                X.estate(r).requests[key],
                X.estate(r).phases[key],
                X.estate(r).executions[key],
                X.estate(r).transitions[key]
            )
        );
    }

    function row41(uint256[17] memory r, bytes32 artistId, RH.JournalEntry memory j)
        public
        view
        returns (bytes memory)
    {
        bytes32 key = j.receipt.recordHash;
        IH.NoticeRow memory row;
        row.position = j.position;
        row.notice = X.dormancy(r).notices[key];
        row.phase = X.dormancy(r).phases[key];
        row.terminal = X.dormancy(r).terminals[X.dormancy(r).terminalForNotice[key]];
        row.transition = X.dormancy(r).transitions[row.terminal.recordHash];
        return abi.encode(row);
    }
}
