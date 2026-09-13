// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecordPublicationTypes as P } from "./StreamArtistRecordPublicationTypes.sol";

/// @notice Authoritative metadata candidate preparation; never grants artist authority itself.
interface IStreamArtistRecordPublicationHost {
    /// @dev Derives the existing generic record preimage from real stored bytes and the exact typed terms,
    ///      with zero signature fields and no authorization backlink. Validates current host/schema/scope
    ///      and returns the supported attestation subject kind for this exact family and schema.
    function requireArtistRecordCandidate(P.Publication calldata publication)
        external
        view
        returns (bytes32 candidateRecordHash, uint8 subjectKind);
}
