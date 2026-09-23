// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev Existing immutable Manager bindings, outside the retained Manager compatibility ABI.
interface IStreamMintFreezeManagerBindings {
    function core() external view returns (address);
    function mintLedger() external view returns (address);
    function moduleRegistry() external view returns (address);
}
