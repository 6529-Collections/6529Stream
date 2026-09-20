// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/domains/revenue/StreamSplitWalletDeployment.sol";

/// @dev Isolates initializer validation with genuine implementation and CREATE2 clones.
/// The production Factory never exposes these deliberately invalid-input entrypoints.
contract SplitWalletInitializationHarness {
    address public immutable implementation;
    mapping(bytes32 => bool) public profileExists;

    constructor() {
        implementation = StreamSplitWalletDeployment.deployImplementation();
    }

    function walletFor(bytes32 profile) public view returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            profile,
                            StreamSplitWalletDeployment.initCodeHash(implementation)
                        )
                    )
                )
            )
        );
    }

    function deployUninitialized(bytes32 profile, bool registered, bytes32 salt)
        public
        returns (IStreamSplitWallet wallet)
    {
        profileExists[profile] = registered;
        wallet = IStreamSplitWallet(StreamSplitWalletDeployment.deploy(implementation, salt));
    }

    function initializeClone(
        IStreamSplitWallet wallet,
        bytes32 profile,
        bytes32 entriesHash,
        bytes32 metadataHash,
        IStreamSplitWallet.SplitEntry[] memory entries,
        address[] memory accounts,
        uint32[] memory shares
    ) public {
        wallet.initialize(profile, entriesHash, metadataHash, entries, accounts, shares);
    }

    function deployAndInitialize(
        bytes32 profile,
        bytes32 entriesHash,
        bytes32 metadataHash,
        IStreamSplitWallet.SplitEntry[] memory entries,
        address[] memory accounts,
        uint32[] memory shares
    ) external returns (IStreamSplitWallet wallet) {
        wallet = deployUninitialized(profile, true, profile);
        initializeClone(wallet, profile, entriesHash, metadataHash, entries, accounts, shares);
    }
}
