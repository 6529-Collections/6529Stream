// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHistoryContentTypes as HC
} from "./StreamArtistRecoveredHistoryContentTypes.sol";
import {
    StreamArtistRecoveredHistoryContentCodec as Codec
} from "./StreamArtistRecoveredHistoryContentCodec.sol";
import {
    StreamArtistRecoveredSanctionConsentHistory as SanctionCodec
} from "./StreamArtistRecoveredSanctionConsentHistory.sol";
import {
    StreamArtistRecoveredDisputeConsentHistory as Consent
} from "./StreamArtistRecoveredDisputeConsentHistory.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

/// @notice The three original complete owner6 decoders, selected only by their closed existing tags.
library StreamArtistRecoveredHistoryRecordConsentCodec {
    function decode(bytes memory raw, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        view
        returns (HC.Bundle memory complete, bool content)
    {
        bytes32 tag = abi.decode(raw, (bytes32));
        content = tag == HC.SCHEMA;
        if (content) {
            complete = Codec.decode(q, p, raw);
        } else if (tag == SanctionCodec.SCHEMA) {
            SanctionCodec.Bundle memory selected = SanctionCodec.decode(q, p, raw);
            complete.base = selected.base;
            complete.sanctions = selected.history;
        } else {
            complete.base = Consent.decode(q, p, raw);
        }
    }
}
