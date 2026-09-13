// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Describes the EIP-712 domain used by a contract's documented signature family.
/// @dev ERC-5267: https://eips.ethereum.org/EIPS/eip-5267.
interface IERC5267 {
    event EIP712DomainChanged();

    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
}
