// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Fixed Core binding exposed by the current metadata router.
/// @dev A read capability; it does not change the router's primary ERC-165 identifier.
interface IStreamMetadataRouterBinding {
    function core() external view returns (address);
}
