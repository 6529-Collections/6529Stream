// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamMintGate.sol";
import "./StreamPreparedNativeContentTypes.sol";

/// @notice Explicit purchase gate capability, never inferred from the original auction gate.
interface IStreamPreparedNativeContentPurchaseGate is IStreamMintGate {
    function publication()
        external
        view
        returns (StreamPreparedNativeContentTypes.Publication memory);
    function gateConfigHash() external view returns (bytes32);
    function manifestBytes() external view returns (bytes memory);
    function itemCount() external view returns (uint256);
    function contentPurchaseVersion() external view returns (bytes32);
}
