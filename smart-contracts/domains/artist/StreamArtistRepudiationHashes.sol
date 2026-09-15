// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistHashes.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import {
    StreamArtistRepudiationTypes as RP
} from "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";

library StreamArtistRepudiationHashes {
    function validate(AD.Filing memory p) internal pure {
        if (
            p.collectionId == 0 || p.bindingGeneration == 0 || p.disputeAction != 4
                || p.reasonHash == 0
        ) {
            revert RP.InvalidRepudiation(0);
        }
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

    function preimage(StreamArtistHashes.Environment memory e, RP.Record memory r)
        public
        pure
        returns (bytes memory)
    {
        return abi.encode(
            keccak256("6529STREAM_ARTIST_ATTRIBUTION_REPUDIATION_RECORD_V1"),
            e.chainId,
            e.registry,
            r.terms.collectionId,
            r.terms.bindingGeneration,
            r.artistId,
            r.signer,
            r.authorityClass,
            r.terms.evidenceHash,
            r.terms.reasonHash,
            r.nonce,
            r.stagedAt,
            r.executableAt
        );
    }

    function recordHash(StreamArtistHashes.Environment memory e, RP.Record memory r)
        public
        pure
        returns (bytes32)
    {
        return keccak256(preimage(e, r));
    }

    function headHash(RP.AuthorityHead memory h) public pure returns (bytes32) {
        return keccak256(abi.encode(h));
    }
}
