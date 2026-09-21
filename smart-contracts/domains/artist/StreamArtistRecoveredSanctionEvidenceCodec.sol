// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Canonical original Coordinator evidence; no newly interpreted actor or owner clock.
library StreamArtistRecoveredSanctionEvidenceCodec {
    function envelope(bytes memory raw) public pure returns (H.Envelope memory e) {
        // The original producer encoded a flat tuple. The identical struct encoding differs
        // only by this single leading offset; compare the full re-encoding including padding.
        bytes memory wrapped = bytes.concat(bytes32(uint256(32)), raw);
        e = abi.decode(wrapped, (H.Envelope));
        if (keccak256(wrapped) != keccak256(abi.encode(e))) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
    }

    function confirmation(bytes memory raw) public pure returns (H.ConfirmationPayload memory p) {
        bytes memory wrapped = bytes.concat(bytes32(uint256(32)), raw);
        p = abi.decode(wrapped, (H.ConfirmationPayload));
        if (keccak256(wrapped) != keccak256(abi.encode(p))) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
    }

    function sanction(bytes memory raw) public pure returns (H.SanctionPayload memory p) {
        bytes memory wrapped = bytes.concat(bytes32(uint256(32)), raw);
        p = abi.decode(wrapped, (H.SanctionPayload));
        if (keccak256(wrapped) != keccak256(abi.encode(p))) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
    }
}
