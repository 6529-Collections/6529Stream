// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPlatformTypes as PW
} from "../../interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    StreamArtistPlatformCorrectionLineageTypes as PL
} from "../../interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";

/// @notice Closed supplemental status interpretation; historical PW.State is never rewritten.
library StreamArtistPlatformCorrectionReads {
    function needed(PW.State memory p) internal pure returns (bool) {
        return p.declaration.recordHash != 0 && p.correction.correctiveGeneration != 0
            && !p.correction.accepted;
    }

    /// @dev Exact six static ABI words; avoid allocating a second tuple inside the STATIC consumer.
    function effectiveEncoded(PW.State memory p, bytes memory raw) internal pure returns (bool) {
        if (raw.length != 192) revert PL.InvalidPlatformContinuation(p.correction.collectionId);
        bytes32 original;
        bytes32 latest;
        uint256 generation;
        uint256 count;
        uint256 accepted;
        bytes32 acceptance;
        assembly ("memory-safe") {
            original := mload(add(raw, 32))
            latest := mload(add(raw, 64))
            generation := mload(add(raw, 96))
            count := mload(add(raw, 128))
            accepted := mload(add(raw, 160))
            acceptance := mload(add(raw, 192))
        }
        bytes32 expected = p.correction.recordHash;
        uint64 first = p.correction.correctiveGeneration;
        bool malformed;
        // Boolean form of the typed reference below. Subtraction is used only with the
        // independently required generation > first predicate, so wrapping cannot admit a row.
        assembly ("memory-safe") {
            first := and(first, 0xffffffffffffffff)
            malformed := or(
                iszero(eq(original, expected)),
                or(shr(64, or(generation, count)), gt(accepted, 1))
            )
            switch iszero(count)
            case 1 {
                malformed := or(malformed, or(or(latest, generation), or(accepted, acceptance)))
            }
            default {
                malformed := or(
                    malformed,
                    or(
                        iszero(latest),
                        or(
                            iszero(gt(generation, first)),
                            or(
                                iszero(eq(count, sub(generation, first))),
                                xor(accepted, iszero(iszero(acceptance)))
                            )
                        )
                    )
                )
            }
            malformed := iszero(iszero(malformed))
        }
        if (malformed) revert PL.InvalidPlatformContinuation(p.correction.collectionId);
        return accepted == 1;
    }

    function effective(PW.State memory p, PL.Status memory r) internal pure returns (bool) {
        if (
            r.originalCorrectionRecord != p.correction.recordHash
                || (r.count == 0
                        ? (r.latestLineageRecord != 0
                            || r.generation != 0
                            || r.effectiveAccepted
                            || r.latestAcceptanceRecord != 0)
                        : (r.latestLineageRecord == 0
                            || r.generation <= p.correction.correctiveGeneration
                            || r.count != r.generation - p.correction.correctiveGeneration
                            || r.effectiveAccepted != (r.latestAcceptanceRecord != 0)))
        ) {
            revert PL.InvalidPlatformContinuation(p.correction.collectionId);
        }
        return r.effectiveAccepted;
    }
}
