// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";

import {
    StreamArtistRecoveredIdentityHydrationState as X
} from "./StreamArtistRecoveredIdentityHydrationState.sol";

import {
    StreamArtistEntropyUnavailabilityStore as Entropy
} from "./StreamArtistEntropyUnavailabilityStore.sol";

/// @notice Fixed Identity export stage in the original owner storage context.
library StreamArtistRecoveredIdentityExportRecordRowsD {
    function row23(uint256[17] memory r, bytes32 artistId, RH.JournalEntry memory j)
        public
        view
        returns (bytes memory)
    {
        bytes32 key = j.receipt.recordHash;
        IH.FindingRow memory row;
        row.position = j.position;
        row.record = X.findings(r).records[key];
        row.admission = X.findings(r).admissions[key];
        row.entropyAdmission = Entropy.state().admissions[key];
        row.entropyOrigin = Entropy.state().origins[key];
        if (
            row.entropyOrigin == address(0) && row.entropyAdmission.target.coordinator != address(0)
        ) row.entropyOrigin = IStreamArtistOwner(address(this)).artistRegistry();
        row.latestForCollection =
            X.findings(r).latest[keccak256(abi.encode(artistId, row.record.terms.collectionId))];
        return abi.encode(row);
    }
}
