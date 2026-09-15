// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Implemented mandatory artist-consent read subset for mint policy and execution.
/// @dev Its own ERC165 identity must not be confused with the full future artist API.
interface IStreamArtistMintConsent {
    function core() external view returns (address);
    function mintManager() external view returns (address);
    function consentMode(uint256 collectionId) external view returns (uint8);
    function isPolicyConsented(uint256 collectionId, bytes32 phaseId, bytes32 policyHash)
        external
        view
        returns (bool consented, bytes32 consentRecordHash);
    /// @notice Reverts unless all accepted-binding, policy and live first-sale floor records match.
    /// @dev Called before phase registration/re-registration and once before each mint transaction.
    function requireMintConsent(uint256 collectionId, bytes32 phaseId, bytes32 policyHash)
        external
        view;
}
