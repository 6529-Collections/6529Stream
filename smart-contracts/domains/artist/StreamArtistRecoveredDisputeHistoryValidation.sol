// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryRows as Rows
} from "./StreamArtistRecoveredDisputeHistoryRows.sol";
import {
    StreamArtistRecoveredDisputeHistoryChains as Chains
} from "./StreamArtistRecoveredDisputeHistoryChains.sol";
import {
    StreamArtistRecoveredDisputeHistoryGuards as Guards
} from "./StreamArtistRecoveredDisputeHistoryGuards.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

/// @notice Canonical complete typed history before any original owner-map import.
library StreamArtistRecoveredDisputeHistoryValidation {
    function validate(D.Bundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        pure
    {
        Rows.validate(b, q, p);
        Chains.validate(b, p);
        Guards.validate(b, p);
    }

    function decode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        public
        pure
        returns (D.Bundle memory b)
    {
        bytes32 tag;
        uint16 version;
        (tag, version, b) = abi.decode(raw, (bytes32, uint16, D.Bundle));
        if (
            tag != D.ATTRIBUTION || version != RH.VERSION
                || keccak256(raw) != keccak256(abi.encode(tag, version, b))
        ) revert RH.InvalidRecoveredHydrationProfile();
        validate(b, q, p);
    }

    function encode(D.Bundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        pure
        returns (bytes memory)
    {
        validate(b, q, p);
        return abi.encode(D.ATTRIBUTION, RH.VERSION, b);
    }
}
