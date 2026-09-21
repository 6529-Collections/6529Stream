// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredDisputeConsentHistory as History
} from "./StreamArtistRecoveredDisputeConsentHistory.sol";
import {
    StreamArtistRecoveredContentConsentHydration as Content
} from "./StreamArtistRecoveredContentConsentHydration.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as Sanction
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistContentRecordsOwner as Records
} from "../../interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    StreamArtistContentTypes as Freeze
} from "../../interfaces/stream/artist/StreamArtistContentTypes.sol";

/// @notice Separate complete history codec; no preceding owner6 tuple is changed.
library StreamArtistRecoveredHistoryContentTypes {
    bytes32 internal constant SCHEMA = keccak256("6529STREAM_ARTIST_RECOVERED_HISTORY_CONTENT_V1");

    struct Bundle {
        History.Bundle base;
        Records.ConsentRecord[] consents;
        Content.Royalty[] royalties;
        Freeze.FreezeRecord[] freezes;
        T.RatificationRecord[] ratifications;
        Sanction.Inventory sanctions;
    }

    function hasContent(Bundle memory b) internal pure returns (bool) {
        return b.consents.length + b.royalties.length + b.freezes.length != 0;
    }

    function content(Bundle memory b) internal pure returns (Content.Bundle memory) {
        return Content.Bundle(b.base.original, b.consents, b.royalties, b.freezes);
    }
}
