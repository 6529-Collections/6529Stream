// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecordPublicationTypes as P } from "./StreamArtistRecordPublicationTypes.sol";

/// @notice Candidate-bound current authorization for one new metadata record publication.
interface IStreamArtistRecordPublication {
    /// @dev Validates stored op24 bytes/provenance and current association, principal and family capability.
    ///      The metadata host separately consumes the detached evidence once and rolls it back on failure.
    ///      Already published records use historical reads and do not require current principal equality.
    function requireRecordPublication(
        bytes32 attestationRecordHash,
        P.Publication calldata publication
    ) external view returns (P.Evidence memory);
}
