// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistPayloadStore } from "./StreamArtistPayloadStore.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistEstateTypes as E
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistIdentityRecoveryTypes as P
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryTypes.sol";

/// @notice Exact original permanent hash preimages, captured only by their execution writers.
library StreamArtistAuthorityPreimages {
    function rotation(uint256 chain, address registry, R.RotationRecord memory r) public {
        StreamArtistPayloadStore.preimage(
            r.recordHash,
            abi.encode(
                bytes32(0x8d7c32ae357c27253fd4480fe9d411cefc64a5634952ed8c8ebe7dcf63257ea5),
                chain,
                registry,
                r.terms.artistId,
                r.terms.oldAddress,
                r.terms.newAddress,
                r.terms.reasonHash,
                r.oldNonce,
                r.transition.stagedAt,
                r.transition.contestEndsAt
            )
        );
    }

    function estate(uint256 chain, address registry, E.RequestRecord memory r) public {
        StreamArtistPayloadStore.preimage(
            r.recordHash,
            abi.encode(
                keccak256("6529STREAM_ARTIST_ESTATE_ACTIVATION_RECORD_V1"),
                chain,
                registry,
                r.terms.artistId,
                r.terms.successor,
                r.terms.evidenceHash,
                r.authorization.nonce,
                r.requestedAt,
                r.noticeEndsAt
            )
        );
    }

    function recovery(uint256 chain, address registry, bytes32 record, P.RecordFields memory fields)
        public
    {
        StreamArtistPayloadStore.preimage(
            record,
            abi.encode(
                bytes32(0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff),
                chain,
                registry,
                fields
            )
        );
    }
}
