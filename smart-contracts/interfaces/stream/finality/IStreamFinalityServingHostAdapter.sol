// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamFinalityHostAdapter.sol";

/// @notice Additive fixed provider capability; host remains the actual serving target.
interface IStreamFinalityServingHostAdapter is IStreamFinalityHostAdapter {
    function evidenceProvider() external view returns (address);
    function evidenceProviderCodeHash() external view returns (bytes32);
    function metadataHost() external view returns (address);
    function metadataHostCodeHash() external view returns (bytes32);
}
