// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistHashes.sol";
import {
    StreamArtistSanctionTypes as S
} from "../../interfaces/stream/artist/StreamArtistSanctionTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Permanent AA-SANCTION preimages and a separate versioned archival byte profile.
/// @dev These functions compute bytes; actual authority, subject and coverage admission is elsewhere.
library StreamArtistSanctionHashes {
    bytes32 internal constant ARCHIVE_SCHEMA = keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_V1");
    bytes32 internal constant ARCHIVE_CANONICALIZATION =
        keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1");

    function digest(
        StreamArtistHashes.Environment memory e,
        S.Terms memory p,
        T.Authorization memory a
    ) public pure returns (bytes32) {
        return StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    bytes32(0x0651c04c186a25456f0dc9ca0a4a29a5537f2aeb0fe7e69cb2d3d202b41549b3),
                    e.core,
                    p.scopeType,
                    p.collectionId,
                    p.tokenId,
                    p.scopeId,
                    p.sanctionSubjectHash,
                    p.statementHash,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function record(StreamArtistHashes.Environment memory e, S.Record memory r)
        public
        pure
        returns (bytes32)
    {
        return keccak256(
            bytes.concat(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_SANCTION_RECORD_V1"),
                    e.chainId,
                    e.registry,
                    r.artistId,
                    r.signer,
                    r.authorityClass,
                    r.terms.scopeType
                ),
                abi.encode(
                    r.terms.collectionId,
                    r.terms.tokenId,
                    r.terms.scopeId,
                    r.terms.sanctionSubjectHash,
                    r.terms.statementHash,
                    r.nonce,
                    r.signedAt
                )
            )
        );
    }

    function subject(S.Subject memory p) public pure returns (bytes32) {
        return keccak256(abi.encode(p));
    }

    /// @notice Archive the actual recorded signature, ceremony and complete admission context together.
    /// @dev No archive hash appears inside its own bytes. The registered ABI profile fixes this tuple
    ///      and its field order; it does not replace the RFC8785 ceremony committed by statementHash.
    function archiveBytes(
        StreamArtistHashes.Environment memory e,
        address finalityRegistry,
        S.Record memory r,
        bytes memory ceremony,
        bytes memory signature
    ) public pure returns (bytes memory) {
        if (
            signature.length == 0 || signature.length > 4096 || ceremony.length == 0
                || ceremony.length > 8192 || r.recordHash != record(e, r)
                || r.terms.statementHash != keccak256(ceremony)
        ) revert S.InvalidSanction();
        return abi.encode(
            ARCHIVE_SCHEMA,
            uint16(1),
            e.chainId,
            e.registry,
            e.core,
            finalityRegistry,
            r,
            ceremony,
            signature
        );
    }
}
