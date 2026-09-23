// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Domain discovery for the separately signed native price-program family.
/// @dev Uses the ERC-5267 return shape. This explicit family getter is a Stream extension;
///      the standard eip712Domain() getter describes the adapter's fixed-sale family.
interface IStreamNativePriceProgramDomain {
    function priceProgramEip712Domain()
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
