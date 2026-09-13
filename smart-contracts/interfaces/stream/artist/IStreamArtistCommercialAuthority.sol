// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact accepted association and current authority for commercial consumers.
/// @dev This read is not a substitute for a commercial signature, consent, or mint admission.
interface IStreamArtistCommercialAuthority {
    /// @notice Composes the accepted binding and current principal, including its real capabilities.
    /// @dev Missing acceptance reverts. Ordinary pairs are ACTIVE1/AUTH_ARTIST1 and
    ///      SUCCEEDED3/AUTH_SUCCESSOR3; the caller still applies its action policy.
    ///      A fresh successor commercial signature requires the supported sale capability.
    ///      Previously consumed same-association obligations do not reverify historical proofs.
    function collectionArtistAuthority(uint256 collectionId)
        external
        view
        returns (
            bytes32 artistId,
            uint64 bindingGeneration,
            bytes32 bindingHash,
            address authorityAddress,
            uint8 authorityClass,
            uint8 authorityStatus,
            uint32 effectiveCapabilities
        );
}
