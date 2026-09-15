// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import "./StreamArtistHashes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

library StreamArtistDisputeHashes {
    function validate(AD.Filing memory p) internal pure {
        if (
            p.collectionId == 0 || p.bindingGeneration == 0
                || (p.disputeAction != 1 && p.disputeAction != 3) || p.evidenceHash == 0
                || p.reasonHash == 0
        ) revert AD.InvalidAttributionDispute(p.collectionId);
    }

    function digest(
        StreamArtistHashes.Environment memory e,
        AD.Filing memory p,
        T.Authorization memory a
    ) public pure returns (bytes32) {
        validate(p);
        return StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamArtistAttributionDispute(address core,uint256 collectionId,uint64 bindingGeneration,uint8 disputeAction,bytes32 evidenceHash,bytes32 reasonHash,uint256 nonce,uint64 deadline)"
                    ),
                    e.core,
                    p.collectionId,
                    p.bindingGeneration,
                    p.disputeAction,
                    p.evidenceHash,
                    p.reasonHash,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function preimage(
        StreamArtistHashes.Environment memory e,
        AD.Filing memory p,
        address signer,
        uint8 class_,
        uint256 nonce,
        uint64 at
    ) public pure returns (bytes memory) {
        return abi.encode(
            keccak256("6529STREAM_ARTIST_DISPUTE_RECORD_V1"),
            e.chainId,
            e.registry,
            p.collectionId,
            p.bindingGeneration,
            p.disputeAction,
            signer,
            class_,
            p.evidenceHash,
            p.reasonHash,
            nonce,
            at
        );
    }

    function record(
        StreamArtistHashes.Environment memory e,
        AD.Filing memory p,
        address signer,
        uint8 class_,
        uint256 nonce,
        uint64 at
    ) public pure returns (bytes32) {
        return keccak256(preimage(e, p, signer, class_, nonce, at));
    }
}
