// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamRevenueResolver.sol";
import "./IStreamSplitFactory.sol";

/// @notice Immutable deployment line shared by the recorder and payer boundary.
interface IStreamPrimarySettlementBindings {
    function core() external view returns (address);
    function moduleRegistry() external view returns (address);
    function revenueResolver() external view returns (IStreamRevenueResolver);
    function splitFactory() external view returns (IStreamSplitFactory);
    function assetPolicyRegistry() external view returns (IStreamAssetPolicyRegistry);
}
