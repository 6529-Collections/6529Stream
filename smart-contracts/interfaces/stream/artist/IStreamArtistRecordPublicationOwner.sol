// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistRotationTypes as R } from "./StreamArtistRotationTypes.sol";
import { StreamArtistRecordPublicationTypes as P } from "./StreamArtistRecordPublicationTypes.sol";

/// @notice Fixed Attribution-owner callback and immutable detached publication evidence.
interface IStreamArtistRecordPublicationOwner {
    struct Record {
        P.Publication publication;
        P.Evidence evidence;
        bytes32 metadataHostCodeHash;
    }

    function recordPublicationAttestation(
        T.ActionContext calldata context,
        T.Binding calldata binding_,
        T.Attestation calldata terms,
        R.AuthorityFact calldata authority,
        uint256 nonce,
        uint64 signedAt,
        bytes calldata statement,
        bytes32 metadataHostCodeHash
    ) external returns (bytes32);

    /// @notice Historical evidence only; publication admission additionally checks current authority.
    function publicationAttestation(bytes32 recordHash) external view returns (Record memory);
}
