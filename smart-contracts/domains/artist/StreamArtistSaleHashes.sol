// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistHashes.sol";
import {
    StreamArtistSaleTypes as Sale
} from "../../interfaces/stream/artist/StreamArtistSaleTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Exact AA-SALE-CONSENT digest and record preimages; owns no authority or sale facts.
library StreamArtistSaleHashes {
    bytes32 internal constant TYPEHASH = keccak256(
        "StreamArtistSaleConsent(address core,address saleAdapter,uint256 collectionId,bytes32 saleId,bytes32 saleConfigHash,uint256 nonce,uint64 deadline)"
    );
    bytes32 internal constant RECORD_DOMAIN = keccak256("6529STREAM_ARTIST_SALE_CONSENT_RECORD_V1");

    function digest(
        StreamArtistHashes.Environment memory e,
        Sale.Consent memory p,
        T.Authorization memory a
    ) public pure returns (bytes32) {
        return StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    TYPEHASH,
                    e.core,
                    p.saleAdapter,
                    p.collectionId,
                    p.saleId,
                    p.saleConfigHash,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function record(
        StreamArtistHashes.Environment memory e,
        Sale.Consent memory p,
        bytes32 artistId,
        address signer,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                RECORD_DOMAIN,
                e.chainId,
                e.registry,
                p.saleAdapter,
                e.core,
                p.collectionId,
                p.saleId,
                p.saleConfigHash,
                artistId,
                signer,
                authorityClass,
                nonce,
                signedAt
            )
        );
    }

    function lookup(uint256 collectionId, bytes32 saleId, bytes32 saleConfigHash)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(collectionId, saleId, saleConfigHash));
    }
}
