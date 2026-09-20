// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPlatformTypes as PW
} from "../../interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    StreamArtistPlatformCorrectionLineageTypes as PL
} from "../../interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";

/// @notice Additive Attribution-owned namespace. Original PW.Store and its one-shot approval are untouched.
library StreamArtistPlatformCorrectionState {
    bytes32 private constant SLOT = keccak256("6529STREAM_ARTIST_PLATFORM_CORRECTION_LINEAGE_V1");

    struct Store {
        mapping(uint256 => PL.Status) heads;
        mapping(bytes32 => PL.Record) records;
        mapping(uint256 => mapping(uint64 => bytes32)) generations;
        mapping(bytes32 => PL.Acceptance) acceptances;
    }

    function store() internal pure returns (Store storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function status(PW.State storage p, uint256 id) internal view returns (PL.Status memory r) {
        PL.Status storage h = store().heads[id];
        return PL.Status(
            p.correction.recordHash,
            h.latestLineageRecord,
            h.generation,
            h.count,
            p.correction.accepted || h.effectiveAccepted,
            h.latestAcceptanceRecord
        );
    }

    function effectiveAccepted(PW.State storage p, uint256 id) internal view returns (bool) {
        return p.correction.accepted || store().heads[id].effectiveAccepted;
    }

    function pins(PW.State memory p) internal pure returns (PL.Pins memory) {
        return PL.Pins(p.declaration, p.contestState, p.contestClaim, p.contestRecord, p.correction);
    }

    function decode(bytes memory raw) internal pure returns (PL.Witness memory w) {
        (bytes32 tag, PL.Witness memory decoded) = abi.decode(raw, (bytes32, PL.Witness));
        if (tag != PL.WITNESS || keccak256(raw) != keccak256(abi.encode(tag, decoded))) {
            revert PL.InvalidPlatformContinuation(0);
        }
        return decoded;
    }

    function tagged(bytes memory raw) internal pure returns (bool) {
        if (raw.length < 32) return false;
        bytes32 tag;
        assembly ("memory-safe") { tag := mload(add(raw, 32)) }
        return tag == PL.WITNESS;
    }
}
