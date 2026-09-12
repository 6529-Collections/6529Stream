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

/// @notice Deploys a sealed foundation and unactivated products on Anvil or Sepolia.
/// @dev No key is read by this script. Supply a Foundry signer or an unlocked local account.
///      Broadcast receipts under broadcast/ identify every deployment and configuration call.
contract DeployCurrentStack is StreamCurrentStackDeployment {
    CurrentDeploymentVm private constant vm =
        CurrentDeploymentVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct DeploymentV2 {
        uint16 schemaVersion;
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
        address roleRegistry;
        address assetPolicy;
        address archivalCheckpoint;
        address archivalCoverage;
        bytes32 archivalConfigurationHash;
        bytes32 deploymentProfileHash;
        bool foundationInitialized;
        bool productsActivated;
        bytes foundationPlan;
        StreamModuleRegistration[] productRegistrations;
        GovernanceActionPolicyEntry[] catalogAdditions;
    }

    function run() external returns (DeploymentV2 memory deployed) {
        require(block.chainid == 31337 || block.chainid == 11155111, "Anvil or Sepolia only");
        deployer = vm.envAddress("STREAM_DEPLOYER");
        require(deployer != address(0), "deployer required");
        protocol = vm.envOr("STREAM_PROTOCOL_TREASURY", deployer);
        localDevelopment = block.chainid == 31337;
        _loadOperatorConfiguration();
        if (!localDevelopment) _loadVRFConfig();
        address selectedArtist = vm.envOr("STREAM_ARTIST", deployer);
        address platform = vm.envOr("STREAM_PLATFORM_SIGNER", deployer);
        vm.startBroadcast(deployer);
        _deployCurrentStack(selectedArtist, platform);
        vm.stopBroadcast();
        deployed.schemaVersion = 2;
        deployed.core = address(core);
        deployed.executor = address(executor);
        deployed.governanceRoot = address(governanceRoot);
        deployed.registry = address(registry);
        deployed.manifest = address(manifest);
        deployed.manager = address(manager);
        deployed.ledger = address(ledger);
        deployed.sale = address(sale);
        deployed.auction = address(auction);
        deployed.splitFactory = address(factory);
        deployed.splitWallet = wallet;
        deployed.entropy = address(entropy);
        deployed.provider = address(provider);
        deployed.metadata = address(router);
        deployed.royalty = address(royalty);
        deployed.artistRegistry = address(artistRegistry);
        deployed.splitProfile = profile;
        deployed.developmentEntropy = localDevelopment;
        deployed.erc20Sale = address(erc20Sale);
        deployed.primaryRevenueResolver = address(primaryRevenue);
        deployed.revenueEscrow = address(revenueEscrow);
        deployed.artistCoordinator = address(artistCoordinator);
        deployed.artistArchive = artistSuite.archive;
        deployed.artistValidator = artistSuite.validator;
        deployed.artistReads = address(artistCoordinator.reads());
        deployed.artistOwners = artistSuite.owners;
        deployed.roleRegistry = address(roles);
        deployed.assetPolicy = address(assetPolicy);
        deployed.archivalCheckpoint = address(archivalCheckpoint);
        deployed.archivalCoverage = address(archivalCoverage);
        deployed.archivalConfigurationHash = archivalCheckpoint.configurationHash();
        deployed.deploymentProfileHash = DEPLOYMENT_HASH;
        deployed.foundationInitialized = executor.genesisInitialized();
        deployed.productsActivated = false;
        deployed.foundationPlan = encodedFoundationPlan;
        deployed.productRegistrations = _productRegistrations();
        deployed.catalogAdditions = _productPolicyAdditions();
    }

    /// @notice Unscheduled catalog additions for the deployed product configuration.
    /// @dev The stateless planner builds these rows outside broadcasting without a script self-call.
    function deploymentCatalogAdditions()
        external
        view
        returns (GovernanceActionPolicyEntry[] memory)
    {
        return _productPolicyAdditions();
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

    function _buildGovernanceFoundationPlan(
        StreamGovernanceGenesisPlan.Configuration memory configuration,
        address payloadRoot,
        StreamSystemManifestUpdate memory update
    )
        internal
        override
        returns (SystemManifestBootstrapBinding memory binding, GenesisBatch[] memory batches)
    {
        vm.stopBroadcast();
        (binding, batches) =
            super._buildGovernanceFoundationPlan(configuration, payloadRoot, update);
        vm.startBroadcast(deployer);
    }
}
