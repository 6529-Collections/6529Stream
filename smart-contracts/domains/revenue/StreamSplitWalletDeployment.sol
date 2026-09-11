// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamSplitWallet.sol";

/// @notice Linked wallet bytecode and CREATE2 mechanics, without profile or authority state.
/// @dev Public library calls delegate into the factory context. The factory remains the CREATE2
/// origin and wallet constructor caller; no proxy or additional wallet authority is introduced.
library StreamSplitWalletDeployment {
    function initCodeHash() public pure returns (bytes32) {
        return keccak256(type(StreamSplitWallet).creationCode);
    }

    function runtimeCodeHash() public pure returns (bytes32) {
        return keccak256(type(StreamSplitWallet).runtimeCode);
    }

    function deploy(bytes32 salt) public returns (address) {
        return address(new StreamSplitWallet{ salt: salt }());
    }
}
