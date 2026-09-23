// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamSplitWallet.sol";
import "../../interfaces/stream/revenue/IStreamSplitWalletImplementation.sol";

/// @notice Fixed implementation deployment and version-4 deterministic clone bytecode.
/// @dev Public calls delegate into the factory: it remains the CREATE/CREATE2 origin.
/// Empty calldata stops without touching storage or calling implementation/recipient code.
/// Nonempty calldata uses the ERC-1167 delegate/return sequence with its jump relocated by 5.
library StreamSplitWalletDeployment {
    function deployImplementation() public returns (address) {
        return address(new StreamSplitWallet());
    }

    function runtimeCode(address implementation) internal pure returns (bytes memory) {
        return abi.encodePacked(
            hex"3615603257", // Empty calldata jumps to the final STOP at offset 0x32.
            hex"363d3d373d3d3d363d73",
            implementation,
            hex"5af43d82803e903d91603057fd5bf3", // Success JUMPDEST relocated to 0x30.
            hex"5b00"
        );
    }

    function initCode(address implementation) internal pure returns (bytes memory) {
        // Copy and return the exact 52-byte runtime, starting after this 10-byte prefix.
        return abi.encodePacked(hex"3d603480600a3d3981f3", runtimeCode(implementation));
    }

    function initCodeHash(address implementation) public pure returns (bytes32) {
        return keccak256(initCode(implementation));
    }

    function runtimeCodeHash(address implementation) public pure returns (bytes32) {
        return keccak256(runtimeCode(implementation));
    }

    function deploy(address implementation, bytes32 salt) public returns (address wallet) {
        bytes memory code = initCode(implementation);
        assembly ("memory-safe") {
            wallet := create2(0, add(code, 32), mload(code), salt)
        }
        if (wallet == address(0)) {
            revert IStreamSplitWalletImplementation.SplitWalletCloneDeploymentFailed(salt);
        }
    }
}
