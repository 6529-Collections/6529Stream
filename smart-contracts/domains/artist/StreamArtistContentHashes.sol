// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistHashes.sol";
import {
    StreamArtistContentTypes as Content
} from "../../interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Permanent content preimages; the environment is always the actual immutable artist facade.
library StreamArtistContentHashes {
    function consentDigest(
        StreamArtistHashes.Environment memory e,
        Content.Consent memory p,
        T.Authorization memory a
    ) public pure returns (bytes32) {
        return StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamArtistContentConsent(address core,address metadataContract,uint256 collectionId,bytes32 familyId,bytes32 newStateHash,uint256 nonce,uint64 deadline)"
                    ),
                    e.core,
                    p.metadataContract,
                    p.collectionId,
                    p.familyId,
                    p.newStateHash,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function freezeDigest(
        StreamArtistHashes.Environment memory e,
        Content.Freeze memory p,
        T.Authorization memory a
    ) public pure returns (bytes32) {
        return StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamArtistContentFreeze(address core,address metadataContract,uint256 collectionId,bytes32[] lockClasses,bytes32 expectedStateHash,uint256 nonce,uint64 deadline)"
                    ),
                    e.core,
                    p.metadataContract,
                    p.collectionId,
                    keccak256(abi.encodePacked(p.lockClasses)),
                    p.expectedStateHash,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function consentRecord(
        StreamArtistHashes.Environment memory e,
        Content.Consent memory p,
        bytes32 artistId,
        address signer,
        uint8 authorityClass,
        uint256 nonce,
        uint64 observedAt
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"),
                e.chainId,
                e.registry,
                p.metadataContract,
                e.core,
                p.collectionId,
                p.familyId,
                p.newStateHash,
                artistId,
                signer,
                authorityClass,
                nonce,
                observedAt
            )
        );
    }

    function freezeRecord(
        StreamArtistHashes.Environment memory e,
        Content.Freeze memory p,
        bytes32 artistId,
        address signer,
        uint8 authorityClass,
        uint256 nonce,
        uint64 observedAt
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CONTENT_FREEZE_RECORD_V1"),
                e.chainId,
                e.registry,
                p.metadataContract,
                e.core,
                p.collectionId,
                p.lockClasses,
                p.expectedStateHash,
                artistId,
                signer,
                authorityClass,
                nonce,
                observedAt
            )
        );
    }

    function validateConsent(Content.Consent memory p) internal pure {
        if (
            p.collectionId == 0 || p.metadataContract == address(0) || p.familyId == bytes32(0)
                || p.newStateHash == bytes32(0)
        ) revert T.InvalidRecord();
    }

    function validateFreeze(Content.Freeze memory p) internal pure {
        uint256 count = p.lockClasses.length;
        if (count == 0 || count > 16) revert T.BoundExceeded(count, 16);
        if (
            p.collectionId == 0 || p.metadataContract == address(0)
                || p.expectedStateHash == bytes32(0)
        ) {
            revert T.InvalidRecord();
        }
        bytes32 prior;
        for (uint256 i; i < count; ++i) {
            bytes32 lockClass = p.lockClasses[i];
            if (lockClass <= prior) revert T.InvalidRecord();
            prior = lockClass;
        }
    }
}
