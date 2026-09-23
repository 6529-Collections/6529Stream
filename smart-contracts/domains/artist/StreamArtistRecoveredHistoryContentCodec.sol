// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHistoryContentTypes as HC
} from "./StreamArtistRecoveredHistoryContentTypes.sol";
import {
    StreamArtistRecoveredHistoryContentRows as Rows
} from "./StreamArtistRecoveredHistoryContentRows.sol";
import {
    StreamArtistRecoveredHistoryContentJournal as Journal
} from "./StreamArtistRecoveredHistoryContentJournal.sol";
import {
    StreamArtistRecoveredSanctionLocalProof as Sanctions
} from "./StreamArtistRecoveredSanctionLocalProof.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

/// @notice Closed successor codec for complete content/ratification and original attribution history.
library StreamArtistRecoveredHistoryContentCodec {
    function tagged(bytes memory raw) internal pure returns (bool) {
        return raw.length >= 32 && abi.decode(raw, (bytes32)) == HC.SCHEMA;
    }

    function decode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        public
        view
        returns (HC.Bundle memory b)
    {
        bytes32 schema;
        uint16 version;
        (schema, version, b) = abi.decode(raw, (bytes32, uint16, HC.Bundle));
        if (
            schema != HC.SCHEMA || version != RH.VERSION
                || keccak256(raw) != keccak256(abi.encode(schema, version, b))
        ) revert RH.InvalidRecoveredHydrationProfile();
        validate(b, q, p);
    }

    function validate(HC.Bundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        view
    {
        if (b.sanctions.sanctions.length != 0) {
            Sanctions.validate(p, 6, q, b.sanctions);
        } else if (
            b.sanctions.catalogues.length != 0 || b.sanctions.operations.length != 0
                || b.sanctions.confirmations.length != 0
        ) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        Rows.validate(b, q, p);
        Journal.validate(b, p);
    }
}
