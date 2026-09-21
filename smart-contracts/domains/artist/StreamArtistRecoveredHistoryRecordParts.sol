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

import {
    StreamArtistRecoveredHistoryRecordTypes as R
} from "./StreamArtistRecoveredHistoryRecordTypes.sol";
import {
    StreamArtistRecoveredAttestationHydration as Attest
} from "./StreamArtistRecoveredAttestationHydration.sol";

/// @notice Closed canonical five-member codec for the additive Platform history profile.
/// @dev Each original nominal member is complete. No field projection or inferred source data.
library StreamArtistRecoveredHistoryRecordParts {
    function encode(R.Bundle memory b) internal pure returns (bytes memory) {
        bytes[5] memory parts = [
            abi.encode(b.history.original),
            abi.encode(b.history.sanctions),
            abi.encode(b.history.platform),
            abi.encode(b.history.bindings),
            abi.encode(b.attestations)
        ];
        return abi.encode(R.ATTRIBUTION, RH.VERSION, parts);
    }

    function decode(bytes memory raw) internal pure returns (R.Bundle memory b) {
        bytes[5] memory parts = members(raw);
        b.history.original = abi.decode(parts[0], (D.Bundle));
        if (keccak256(parts[0]) != keccak256(abi.encode(b.history.original))) _invalid();
        b.history.sanctions = abi.decode(parts[1], (H.Inventory));
        if (keccak256(parts[1]) != keccak256(abi.encode(b.history.sanctions))) _invalid();
        b.history.platform = abi.decode(parts[2], (P.Platform));
        if (keccak256(parts[2]) != keccak256(abi.encode(b.history.platform))) _invalid();
        b.history.bindings = abi.decode(parts[3], (CB.Bundle));
        if (keccak256(parts[3]) != keccak256(abi.encode(b.history.bindings))) _invalid();
        b.attestations = abi.decode(parts[4], (Attest.Bundle));
        if (keccak256(parts[4]) != keccak256(abi.encode(b.attestations))) _invalid();
    }

    function members(bytes memory raw) internal pure returns (bytes[5] memory parts) {
        bytes32 tag;
        uint16 version;
        (tag, version, parts) = abi.decode(raw, (bytes32, uint16, bytes[5]));
        if (
            tag != R.ATTRIBUTION || version != RH.VERSION
                || keccak256(raw) != keccak256(abi.encode(tag, version, parts))
        ) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
