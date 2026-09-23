// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistBindingCorrectionTypes as BC
} from "../../interfaces/stream/artist/IStreamArtistBindingCorrection.sol";
import { StreamArtistHashes as H } from "./StreamArtistHashes.sol";

library StreamArtistBindingCorrectionHashes {
    function hash(H.Environment memory e, uint256 id, bytes32 bindingHash, BC.Approval memory a)
        public
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_BINDING_CORRECTION_RECORD_V1"),
                e.chainId,
                e.registry,
                e.core,
                e.manager,
                id,
                bindingHash,
                a
            )
        );
    }
}
