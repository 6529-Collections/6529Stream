// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../revenue/IStreamRevenueEscrow.sol";

/// @notice Read and event surface for the current fixed-profile funding path.
interface IStreamSaleFunding {
    error InvalidSaleFundingConfiguration();
    error SaleFundingBindingChanged(address target);
    error SaleFundingProfileInvalid(bytes32 profileId, address wallet);
    error SaleFundingAssetInactive(address asset);
    error InsufficientSaleFundingGas(uint256 gasLimit, uint256 available);
    error SaleFundingTokenReadFailed(address asset, bytes4 selector);
    error SaleFundingTokenCallFailed(address asset, bytes4 selector);
    error SaleFundingAmountMismatch(address asset);
    error SaleFundingAllowanceMismatch(address asset, uint256 actual, uint256 expected);
    error SaleFundingEscrowMismatch(address asset);

    event SaleRevenueFunded(
        uint16 schemaVersion,
        bytes32 indexed authorizationId,
        bytes32 indexed operationRoot,
        bytes32 indexed profileId,
        address wallet,
        address asset,
        uint256 amount,
        bool escrowed
    );

    function revenueEscrow() external view returns (IStreamRevenueEscrow);
    function fundingFactoryCodeHash() external view returns (bytes32);
    function fundingEscrowCodeHash() external view returns (bytes32);
}
