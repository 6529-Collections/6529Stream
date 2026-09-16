// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistHashes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistEstateTypes as Estate
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";

/// @notice Exact permanent AA-ESTATE signature and primary record field order.
library StreamArtistEstateHashes {
    function digest(
        StreamArtistHashes.Environment memory e,
        Estate.Request memory p,
        T.Authorization memory a
    ) internal pure returns (bytes32) {
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "StreamArtistEstateActivation(bytes32 artistId,address successor,bytes32 evidenceHash,uint256 nonce,uint64 deadline)"
                ),
                p.artistId,
                p.successor,
                p.evidenceHash,
                a.nonce,
                a.time
            )
        );
        return StreamArtistHashes.typed(e, body);
    }

    function record(
        StreamArtistHashes.Environment memory e,
        Estate.Request memory p,
        uint256 nonce,
        uint64 requestedAt,
        uint64 noticeEndsAt
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ESTATE_ACTIVATION_RECORD_V1"),
                e.chainId,
                e.registry,
                p.artistId,
                p.successor,
                p.evidenceHash,
                nonce,
                requestedAt,
                noticeEndsAt
            )
        );
    }
}
