// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Historical association evidence; callers independently obtain the current Binding.
interface IStreamArtistEconomicsEvidence {
    struct Association {
        bytes32 artistId;
        uint64 bindingGeneration;
        bytes32 bindingHash;
        bytes32 payloadHash;
        bytes32 originalRecord;
    }

    event ArtistEconomicsConsentAssociated(
        uint16 schemaVersion,
        bytes32 indexed recordHash,
        bytes32 indexed artistId,
        bytes32 indexed bindingHash,
        uint64 bindingGeneration,
        bytes32 payloadHash,
        bytes32 originalRecord
    );

    /// @notice Looks up a stored consent for the exact supplied historical association.
    /// @dev This is not an assertion that the supplied association is current.
    function economicsRecordForBinding(
        T.EconomicsConsent calldata payload,
        bytes32 artistId,
        uint64 bindingGeneration,
        bytes32 bindingHash
    ) external view returns (bytes32);

    function economicsRecordAssociation(bytes32 recordHash)
        external
        view
        returns (Association memory);
}
