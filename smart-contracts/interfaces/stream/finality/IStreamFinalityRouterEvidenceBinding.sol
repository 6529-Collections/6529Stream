// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Fixed source identities and explicit current-candidate admission for Router evidence.
interface IStreamFinalityRouterEvidenceBinding {
    function coreCodeHash() external view returns (bytes32);
    function metadataHostCodeHash() external view returns (bytes32);
    function metadataRouter() external view returns (address);
    function metadataRouterCodeHash() external view returns (bytes32);
    function scopeMembershipHost() external view returns (address);
    function scopeMembershipHostCodeHash() external view returns (bytes32);
    /// @notice Current eligible pointers and the saved original-Finality anchor must match.
    /// @dev Constructor and historical component reads do not invoke this gate.
    function requireCurrentRouterCandidate(uint256 collectionId, address finalityRegistry)
        external
        view;
}
