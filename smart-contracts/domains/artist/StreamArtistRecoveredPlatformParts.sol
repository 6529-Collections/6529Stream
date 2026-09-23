// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Closed canonical four-member codec for the additive Platform history profile.
/// @dev Each original nominal member is complete. No field projection or inferred source data.
library StreamArtistRecoveredPlatformParts {
    function encode(P.Bundle memory b) internal pure returns (bytes memory) {
        bytes[4] memory parts = [
            abi.encode(b.original),
            abi.encode(b.sanctions),
            abi.encode(b.platform),
            abi.encode(b.bindings)
        ];
        return abi.encode(P.ATTRIBUTION, RH.VERSION, parts);
    }

    function decode(bytes memory raw) internal pure returns (P.Bundle memory b) {
        bytes[4] memory parts = members(raw);
        b.original = abi.decode(parts[0], (D.Bundle));
        if (keccak256(parts[0]) != keccak256(abi.encode(b.original))) _invalid();
        b.sanctions = abi.decode(parts[1], (H.Inventory));
        if (keccak256(parts[1]) != keccak256(abi.encode(b.sanctions))) _invalid();
        b.platform = abi.decode(parts[2], (P.Platform));
        if (keccak256(parts[2]) != keccak256(abi.encode(b.platform))) _invalid();
        b.bindings = abi.decode(parts[3], (CB.Bundle));
        if (keccak256(parts[3]) != keccak256(abi.encode(b.bindings))) _invalid();
    }

    function members(bytes memory raw) internal pure returns (bytes[4] memory parts) {
        bytes32 tag;
        uint16 version;
        (tag, version, parts) = abi.decode(raw, (bytes32, uint16, bytes[4]));
        if (
            tag != P.ATTRIBUTION || version != RH.VERSION
                || keccak256(raw) != keccak256(abi.encode(tag, version, parts))
        ) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
