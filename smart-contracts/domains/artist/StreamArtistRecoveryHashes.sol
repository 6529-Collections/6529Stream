// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistHashes.sol";
import {
    StreamArtistRecoveryTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistRecoveryTypes.sol";

/// @notice Exact permanent AA-RECOVERY preimages. These helpers do not admit authority or evidence.
library StreamArtistRecoveryHashes {
    struct ApprovalPreimage {
        bytes32 domain;
        uint256 chainId;
        address registry;
        address finalityRegistry;
        uint256 collectionId;
        bytes32 finalityRecordHash;
        bytes32 recoveryManifestHash;
        bytes32 artistId;
        address signer;
        uint8 authorityClass;
        uint256 nonce;
        uint64 signedAt;
    }

    function approvalDigest(
        StreamArtistHashes.Environment memory e,
        Recovery.ApprovalTerms memory p,
        uint256 nonce,
        uint64 deadline
    ) public pure returns (bytes32) {
        return StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    bytes32(0x242bffdf15416a6743c57bd362683aa2933edcd42a4ef176f4e983a745eee511),
                    e.core,
                    p.finalityRegistry,
                    p.collectionId,
                    p.finalityRecordHash,
                    p.recoveryManifestHash,
                    nonce,
                    deadline
                )
            )
        );
    }

    function approvalRecord(
        StreamArtistHashes.Environment memory e,
        Recovery.ApprovalRecord memory r
    ) public pure returns (bytes32) {
        ApprovalPreimage memory p;
        p.domain = keccak256("6529STREAM_ARTIST_RECOVERY_APPROVAL_RECORD_V1");
        p.chainId = e.chainId;
        p.registry = e.registry;
        p.finalityRegistry = r.terms.finalityRegistry;
        p.collectionId = r.terms.collectionId;
        p.finalityRecordHash = r.terms.finalityRecordHash;
        p.recoveryManifestHash = r.terms.recoveryManifestHash;
        p.artistId = r.artistId;
        p.signer = r.signer;
        p.authorityClass = r.authorityClass;
        p.nonce = r.nonce;
        p.signedAt = r.signedAt;
        return keccak256(abi.encode(p));
    }

    function findingRecord(StreamArtistHashes.Environment memory e, Recovery.FindingRecord memory r)
        public
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_UNAVAILABILITY_FINDING_RECORD_V1"),
                e.chainId,
                e.registry,
                r.terms.artistId,
                r.terms.collectionId,
                r.terms.evidenceHash,
                r.terms.reasonHash,
                r.governanceActionId,
                r.noticeEndsAt,
                r.recordedAt
            )
        );
    }
}
