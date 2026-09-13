// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import "./IStreamArtworkFinalityComponents.sol";

/// @notice Immutable translation of a host's facts into a finality component identity.
interface IStreamFinalityHostAdapter is
    IERC165,
    IStreamArtworkFinalityComponent,
    IStreamArtworkScopedFinalityComponent
{
    function core() external view returns (address);
    function host() external view returns (address);
    function componentType() external view returns (bytes32);
    function hostCodeHash() external view returns (bytes32);
    function coreCodeHash() external view returns (bytes32);
    function hostPointerType() external view returns (bytes32);

    /// @notice Checks eligibility for current discovery; historical reads do not call this.
    function requireCurrentSelection() external view;
}
