// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentStackDeployment.sol";

interface CurrentDeploymentVm {
    function envAddress(string calldata key) external view returns (address);
    function envUint(string calldata key) external view returns (uint256);
    function envBytes32(string calldata key) external view returns (bytes32);
    function envOr(string calldata key, address defaultValue) external view returns (address);
    function envOr(string calldata key, uint256 defaultValue) external view returns (uint256);
    function envOr(string calldata key, bool defaultValue) external view returns (bool);
    function startBroadcast(address broadcaster) external;
    function stopBroadcast() external;
}

/// @notice Deploys an unaudited current-stack development instance to Anvil or Sepolia.
/// @dev No key is read by this script. Supply a Foundry signer or an unlocked local account.
///      Broadcast receipts under broadcast/ identify every deployment and configuration call.
contract DeployCurrentStack is StreamCurrentStackDeployment {
    CurrentDeploymentVm private constant vm =
        CurrentDeploymentVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct DeploymentAddresses {
        address core;
        address executor;
        address governanceRoot;
        address registry;
        address manifest;
        address manager;
        address ledger;
        address sale;
        address auction;
        address splitFactory;
        address splitWallet;
        address entropy;
        address provider;
        address metadata;
        address royalty;
        address artistRegistry;
        bytes32 splitProfile;
        bool developmentEntropy;
        address erc20Sale;
        address primaryRevenueResolver;
        address revenueEscrow;
        address artistCoordinator;
        address artistArchive;
        address artistValidator;
        address artistReads;
        address[7] artistOwners;
        bytes32 activationActionId;
        uint64 activationNotBefore;
        bytes activationPlan; // Combined artist/reveal five-call plan; use ActivateCurrentRevealAuthority.
    }

    function run() external returns (DeploymentAddresses memory deployed) {
        require(block.chainid == 31337 || block.chainid == 11155111, "Anvil or Sepolia only");
        deployer = vm.envAddress("STREAM_DEPLOYER");
        require(deployer != address(0), "deployer required");
        protocol = vm.envOr("STREAM_PROTOCOL_TREASURY", deployer);
        localDevelopment = block.chainid == 31337;
        if (!localDevelopment) _loadVRFConfig();
        address selectedArtist = vm.envOr("STREAM_ARTIST", deployer);
        address platform = vm.envOr("STREAM_PLATFORM_SIGNER", deployer);
        vm.startBroadcast(deployer);
        _deployCurrentStack(selectedArtist, platform);
        vm.stopBroadcast();
        deployed = DeploymentAddresses(
            address(core),
            address(executor),
            address(governanceRoot),
            address(registry),
            address(manifest),
            address(manager),
            address(ledger),
            address(sale),
            address(auction),
            address(factory),
            wallet,
            address(entropy),
            address(provider),
            address(router),
            address(royalty),
            address(artistRegistry),
            profile,
            localDevelopment,
            address(erc20Sale),
            address(primaryRevenue),
            address(revenueEscrow),
            address(artistCoordinator),
            artistSuite.archive,
            artistSuite.validator,
            address(artistCoordinator.reads()),
            artistSuite.owners,
            artistActivationId,
            artistActivationNotBefore,
            encodedArtistActivationPlan
        );
    }

    function _artistActivationTimestamp() internal view override returns (uint64) {
        uint256 value = vm.envOr("STREAM_ARTIST_ACTIVATION_NOT_BEFORE", block.timestamp + 49 hours);
        require(value <= type(uint64).max - 7 days, "activation time out of range");
        return uint64(value);
    }

    function _loadVRFConfig() private {
        // Subscription funding and adding the deployed adapter as a consumer are external
        // Chainlink operations. Deployment does not claim those have been completed.
        vrfConfig.vrfCoordinator = vm.envAddress("STREAM_VRF_COORDINATOR");
        vrfConfig.subscriptionId = vm.envUint("STREAM_VRF_SUBSCRIPTION_ID");
        vrfConfig.keyHash = vm.envBytes32("STREAM_VRF_KEY_HASH");
        uint256 confirmations = vm.envOr("STREAM_VRF_CONFIRMATIONS", uint256(3));
        uint256 callbackGas = vm.envOr("STREAM_VRF_CALLBACK_GAS", uint256(1500000));
        uint256 maximumCallbackGas = vm.envOr("STREAM_VRF_MAX_CALLBACK_GAS", uint256(2500000));
        require(
            confirmations <= type(uint16).max && callbackGas <= type(uint32).max
                && maximumCallbackGas <= type(uint32).max,
            "VRF config out of range"
        );
        vrfConfig.requestConfirmations = uint16(confirmations);
        vrfConfig.callbackGasLimit = uint32(callbackGas);
        vrfConfig.maximumCallbackGasLimit = uint32(maximumCallbackGas);
        vrfConfig.nativePayment = vm.envOr("STREAM_VRF_NATIVE_PAYMENT", true);
    }
}
