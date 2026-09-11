// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistHashes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Stateless typed AA economics hashing shared by ingress, orchestration and record owners.
/// @dev The explicit environment is the pinned registry identity, never this linked library.
///      No authorization, nonce, owner storage or caller-dependent behavior lives here.
library StreamArtistEconomicsHashes {
    function economicsDigest(
        StreamArtistHashes.Environment memory e,
        T.EconomicsConsent memory p,
        uint256 nonce,
        uint64 deadline
    ) public pure returns (bytes32) {
        return StreamArtistHashes.economicsDigest(e, p, T.Authorization(nonce, deadline, ""));
    }

    function economicsRecord(
        StreamArtistHashes.Environment memory e,
        T.EconomicsConsent memory p,
        bytes32 designation,
        bytes32 artistId,
        address signer,
        uint256 nonce,
        uint64 signedAt
    ) public pure returns (bytes32) {
        return StreamArtistHashes.economicsRecord(
            e, p, designation, artistId, signer, nonce, signedAt
        );
    }

    function royaltyFreezeDigest(
        StreamArtistHashes.Environment memory e,
        T.RoyaltyFreeze memory p,
        uint256 nonce,
        uint64 deadline
    ) public pure returns (bytes32) {
        return StreamArtistHashes.royaltyFreezeDigest(e, p, T.Authorization(nonce, deadline, ""));
    }

    function royaltyFreezeRecord(
        StreamArtistHashes.Environment memory e,
        T.RoyaltyFreeze memory p,
        bytes32 artistId,
        address signer,
        uint256 nonce,
        uint64 signedAt
    ) public pure returns (bytes32) {
        return StreamArtistHashes.royaltyFreezeRecord(e, p, artistId, signer, nonce, signedAt);
    }
}
