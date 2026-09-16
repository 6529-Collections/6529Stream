// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    StreamArtistIdentityDismissalTypes as Dismissal
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";

/// @notice Exact fixed-Identity notice joins for original op33 and op58 contexts.
library StreamArtistDormancyResolutionReads {
    function pending(bytes32 artistId) internal view returns (bytes32 proof) {
        (bytes32 notice, uint8 phase, bytes32 terminal) =
            _read(abi.encodeCall(IStreamArtistDormancyOwner.dormancyNotice, (artistId)), artistId);
        if (notice == 0 || phase != 1 || terminal != 0) revert Dorm.InvalidDormancy(artistId);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_PENDING_CONTEXT_V1"), notice, phase, terminal
            )
        );
    }

    function resolution(Dismissal.Cause memory cause)
        internal
        view
        returns (bytes32 proof, uint8 restoredStatus)
    {
        restoredStatus = cause.facts.priorStatus;
        if (restoredStatus != 2) return (bytes32(0), restoredStatus);
        (bytes32 notice, uint8 phase, bytes32 terminal) = _read(
            abi.encodeCall(
                IStreamArtistDormancyOwner.dormancyResolutionState,
                (cause.facts.artistId, cause.causeHash)
            ),
            cause.facts.artistId
        );
        if (
            notice == 0 || (phase != 1 && phase != 2)
                || (phase == 1 ? terminal != 0 : terminal == 0)
        ) revert Dorm.InvalidDormancy(cause.facts.artistId);
        proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_RESOLUTION_CONTEXT_V1"),
                cause.causeHash,
                notice,
                phase,
                terminal
            )
        );
        if (phase == 2) restoredStatus = 1;
    }

    function _read(bytes memory data, bytes32 id) private view returns (bytes32, uint8, bytes32) {
        bytes memory raw = new bytes(96);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), address(), add(data, 32), mload(data), add(raw, 32), 96)
            size := returndatasize()
        }
        if (!ok || size != 96) revert Dorm.InvalidDormancy(id);
        return abi.decode(raw, (bytes32, uint8, bytes32));
    }
}
