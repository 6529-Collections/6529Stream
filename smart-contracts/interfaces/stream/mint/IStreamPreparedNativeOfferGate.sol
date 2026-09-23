// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamMintGate.sol";
import "./StreamPreparedNativeContentTypes.sol";

/// @notice Explicit offer capability, separate from the original curated-purchase gate.
interface IStreamPreparedNativeOfferGate is IStreamMintGate {
    /// @dev This gate is for selected offers. Unselected offers use no phase gate and
    /// are authenticated by the Manager's separate full-payload offer admission.
    function publication()
        external
        view
        returns (StreamPreparedNativeContentTypes.Publication memory);
    function gateConfigHash() external view returns (bytes32);
    function manifestBytes() external view returns (bytes memory);
    function itemCount() external view returns (uint256);
    function offerPurchaseVersion() external pure returns (bytes32);
}
