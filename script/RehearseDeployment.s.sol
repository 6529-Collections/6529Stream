// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/AuctionContract.sol";
import "../smart-contracts/DependencyRegistry.sol";
import "../smart-contracts/RandomizerRNG.sol";
import "../smart-contracts/RandomizerVRF.sol";
import "../smart-contracts/StreamAssetPolicyRegistry.sol";
import "../smart-contracts/StreamAdmins.sol";
import "../smart-contracts/StreamContractMetadata.sol";
import "../smart-contracts/StreamCore.sol";
import "../smart-contracts/StreamCuratorsPool.sol";
import "../smart-contracts/StreamDrops.sol";
import "../smart-contracts/StreamMinter.sol";
import "../smart-contracts/StreamSplitFactory.sol";

interface ScriptVm {
    function startBroadcast(address broadcaster) external;
    function stopBroadcast() external;
    function envAddress(string calldata key) external view returns (address value);
    function envString(string calldata key) external view returns (string memory value);
    function envUint(string calldata key) external view returns (uint256 value);
}

contract RehearseDeployment {
    ScriptVm private constant vm =
        ScriptVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string public constant MANIFEST_SCHEMA_VERSION = "6529stream.deployment-manifest.v1";
    string public constant PROTOCOL_VERSION = "0.1.0";
    string public constant DEPLOYMENT_VERSION = "anvil-6529stream-v0.1.0-001";
    string public constant SEPOLIA_DEPLOYMENT_VERSION = "sepolia-6529stream-v0.1.0-001";
    uint256 public constant SEPOLIA_CHAIN_ID = 11_155_111;
    bytes32 public constant LOCAL_DEPENDENCY_KEY =
        keccak256("6529Stream.local.rehearsal.dependency.v1");

    struct DeploymentConfig {
        string protocolVersion;
        string deploymentVersion;
        string contractMetadataURI;
        address deployer;
        address adminSafe;
        address pauseGuardian;
        address emergencyRecipient;
        address tdhSigner;
        address payout;
        address delegation;
        address vrfCoordinator;
        address arrngController;
        uint64 vrfSubscriptionId;
    }

    struct DeploymentResult {
        address admins;
        address dependencyRegistry;
        address core;
        address contractMetadata;
        address curatorsPool;
        address minter;
        address drops;
        address auctions;
        address randomizerVrf;
        address randomizerRng;
        address assetPolicyRegistry;
        address splitFactory;
        uint256 sampleCollectionId;
        uint256 sampleMintStart;
        uint256 sampleMintEnd;
        uint256 chainId;
        bytes32 manifestHash;
    }

    function defaultLocalConfig() public pure returns (DeploymentConfig memory config) {
        config = DeploymentConfig({
            protocolVersion: PROTOCOL_VERSION,
            deploymentVersion: DEPLOYMENT_VERSION,
            contractMetadataURI: "ipfs://6529stream-contract-metadata/rehearsal.json",
            deployer: address(0x0000000000000000000000000000000000006537),
            adminSafe: address(0x0000000000000000000000000000000000006529),
            pauseGuardian: address(0x0000000000000000000000000000000000006530),
            emergencyRecipient: address(0x0000000000000000000000000000000000006531),
            tdhSigner: address(0x0000000000000000000000000000000000006532),
            payout: address(0x0000000000000000000000000000000000006533),
            delegation: address(0x0000000000000000000000000000000000006534),
            vrfCoordinator: address(0x0000000000000000000000000000000000006535),
            arrngController: address(0x0000000000000000000000000000000000006536),
            vrfSubscriptionId: 6529
        });
    }

    function run() external returns (DeploymentResult memory result) {
        result = deployLocal(defaultLocalConfig());
    }

    function runSepolia() external returns (DeploymentResult memory result) {
        require(block.chainid == SEPOLIA_CHAIN_ID, "Wrong Sepolia chain");
        result = deployLocal(sepoliaConfigFromEnv());
    }

    function sepoliaConfigFromEnv() public view returns (DeploymentConfig memory config) {
        uint256 subscriptionId = vm.envUint("SEPOLIA_VRF_SUBSCRIPTION_ID");
        require(subscriptionId <= type(uint64).max, "VRF subscription too large");

        config = DeploymentConfig({
            protocolVersion: PROTOCOL_VERSION,
            deploymentVersion: SEPOLIA_DEPLOYMENT_VERSION,
            contractMetadataURI: vm.envString("SEPOLIA_CONTRACT_METADATA_URI"),
            deployer: vm.envAddress("SEPOLIA_DEPLOYER_ADDRESS"),
            adminSafe: vm.envAddress("SEPOLIA_ADMIN_SAFE"),
            pauseGuardian: vm.envAddress("SEPOLIA_PAUSE_GUARDIAN"),
            emergencyRecipient: vm.envAddress("SEPOLIA_EMERGENCY_RECIPIENT"),
            tdhSigner: vm.envAddress("SEPOLIA_DROP_SIGNER"),
            payout: vm.envAddress("SEPOLIA_PAYOUT"),
            delegation: vm.envAddress("SEPOLIA_DELEGATION_REGISTRY"),
            vrfCoordinator: vm.envAddress("SEPOLIA_VRF_COORDINATOR"),
            arrngController: vm.envAddress("SEPOLIA_ARRNG_CONTROLLER"),
            // Bound checked above; keep the script config ABI compact.
            // forge-lint: disable-next-line(unsafe-typecast)
            vrfSubscriptionId: uint64(subscriptionId)
        });
    }

    function deployLocal(DeploymentConfig memory config)
        public
        returns (DeploymentResult memory result)
    {
        _requireConfig(config);
        vm.startBroadcast(config.deployer);

        DeployedContracts memory deployed = _deployContracts(config);
        _configureAdminCeremony(deployed.admins, config);
        _wireContracts(deployed);

        (uint256 collectionId, uint256 mintStart, uint256 mintEnd) =
            _createSampleCollection(deployed, config);

        result = _deploymentResult(config, deployed, collectionId, mintStart, mintEnd);

        deployed.admins.registerAdmin(config.deployer, false);
        deployed.assetPolicyRegistry.transferOwnership(config.adminSafe);
        deployed.core.transferOwnership(config.adminSafe);
        deployed.admins.transferOwnership(config.adminSafe);

        vm.stopBroadcast();
    }

    struct DeployedContracts {
        StreamAdmins admins;
        DependencyRegistry dependencyRegistry;
        StreamCore core;
        StreamContractMetadata contractMetadata;
        StreamCuratorsPool curatorsPool;
        StreamMinter minter;
        StreamDrops drops;
        StreamAuctions auctions;
        NextGenRandomizerVRF randomizerVrf;
        NextGenRandomizerRNG randomizerRng;
        StreamAssetPolicyRegistry assetPolicyRegistry;
        StreamSplitFactory splitFactory;
    }

    function _deployContracts(DeploymentConfig memory config)
        private
        returns (DeployedContracts memory deployed)
    {
        StreamAdmins admins = new StreamAdmins(config.tdhSigner);
        DependencyRegistry dependencyRegistry = new DependencyRegistry(address(admins));
        StreamCore core =
            new StreamCore("6529 Stream", "STREAM", address(admins), address(dependencyRegistry));
        StreamContractMetadata contractMetadata =
            new StreamContractMetadata(address(core), address(admins), config.contractMetadataURI);
        StreamCuratorsPool curatorsPool = new StreamCuratorsPool(address(admins), config.delegation);
        StreamMinter minter = new StreamMinter(address(core), address(admins), address(0));
        StreamDrops drops = new StreamDrops(
            config.tdhSigner, address(minter), address(admins), config.payout, address(curatorsPool)
        );
        StreamAuctions auctions = new StreamAuctions(
            address(minter),
            address(core),
            address(admins),
            address(drops),
            config.payout,
            address(curatorsPool)
        );
        NextGenRandomizerVRF randomizerVrf = new NextGenRandomizerVRF(
            config.vrfSubscriptionId, config.vrfCoordinator, address(core), address(admins)
        );
        NextGenRandomizerRNG randomizerRng =
            new NextGenRandomizerRNG(address(core), address(admins), config.arrngController);
        StreamAssetPolicyRegistry assetPolicyRegistry = new StreamAssetPolicyRegistry();
        StreamSplitFactory splitFactory = new StreamSplitFactory(assetPolicyRegistry);

        deployed = DeployedContracts({
            admins: admins,
            dependencyRegistry: dependencyRegistry,
            core: core,
            contractMetadata: contractMetadata,
            curatorsPool: curatorsPool,
            minter: minter,
            drops: drops,
            auctions: auctions,
            randomizerVrf: randomizerVrf,
            randomizerRng: randomizerRng,
            assetPolicyRegistry: assetPolicyRegistry,
            splitFactory: splitFactory
        });
    }

    function _configureAdminCeremony(StreamAdmins admins, DeploymentConfig memory config) private {
        admins.registerAdmin(config.deployer, true);
        admins.registerAdmin(config.adminSafe, true);
        admins.registerPauseGuardian(config.pauseGuardian, true);
        admins.registerUnpauseAdmin(config.adminSafe, true);
        admins.registerSignerManager(config.adminSafe, true);
        admins.updateEmergencyRecipient(config.emergencyRecipient);
    }

    function _wireContracts(DeployedContracts memory deployed) private {
        deployed.core.updateContracts(2, address(deployed.minter));
        deployed.minter.updateContracts(3, address(deployed.drops));
        deployed.drops.updateAuctionContract(address(deployed.auctions));
        deployed.admins.registerSignerLifecycleTarget(address(deployed.drops), true);
    }

    function _createSampleCollection(
        DeployedContracts memory deployed,
        DeploymentConfig memory config
    ) private returns (uint256 collectionId, uint256 mintStart, uint256 mintEnd) {
        string[] memory dependencyScript = new string[](1);
        dependencyScript[0] = "function draw(){return '6529Stream rehearsal';}";
        deployed.dependencyRegistry
            .addDependencyWithProvenance(
                LOCAL_DEPENDENCY_KEY, dependencyScript, "local-anvil-rehearsal"
            );

        collectionId = deployed.core.newCollectionIndex();
        string[] memory collectionScript = new string[](1);
        collectionScript[0] = "function setup(){return '6529Stream';}";
        deployed.core
            .createCollection(
                "6529 Stream Rehearsal",
                "6529",
                "Local deployment rehearsal collection",
                "https://6529.io",
                "CC0",
                "ipfs://6529stream-rehearsal/",
                "https://cdn.6529.io/stream/rehearsal.js",
                LOCAL_DEPENDENCY_KEY,
                collectionScript
            );
        deployed.core.setCollectionData(collectionId, config.payout, 5, 10, 1 days);
        deployed.core.addRandomizer(collectionId, address(deployed.randomizerVrf));
        mintStart = block.timestamp;
        mintEnd = block.timestamp + 30 days;
        deployed.minter.setCollectionPhases(collectionId, mintStart, mintEnd);
    }

    function _deploymentResult(
        DeploymentConfig memory config,
        DeployedContracts memory deployed,
        uint256 collectionId,
        uint256 mintStart,
        uint256 mintEnd
    ) private view returns (DeploymentResult memory result) {
        result = DeploymentResult({
            admins: address(deployed.admins),
            dependencyRegistry: address(deployed.dependencyRegistry),
            core: address(deployed.core),
            contractMetadata: address(deployed.contractMetadata),
            curatorsPool: address(deployed.curatorsPool),
            minter: address(deployed.minter),
            drops: address(deployed.drops),
            auctions: address(deployed.auctions),
            randomizerVrf: address(deployed.randomizerVrf),
            randomizerRng: address(deployed.randomizerRng),
            assetPolicyRegistry: address(deployed.assetPolicyRegistry),
            splitFactory: address(deployed.splitFactory),
            sampleCollectionId: collectionId,
            sampleMintStart: mintStart,
            sampleMintEnd: mintEnd,
            chainId: block.chainid,
            manifestHash: _manifestHash(config, block.chainid, collectionId, mintStart, mintEnd)
        });
    }

    function _manifestHash(
        DeploymentConfig memory config,
        uint256 chainId,
        uint256 collectionId,
        uint256 mintStart,
        uint256 mintEnd
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                MANIFEST_SCHEMA_VERSION,
                _versionHash(config),
                _adminHash(config),
                _contractMetadataHash(config),
                _externalDependencyHash(config),
                chainId,
                collectionId,
                mintStart,
                mintEnd
            )
        );
    }

    function _versionHash(DeploymentConfig memory config) private pure returns (bytes32) {
        return keccak256(abi.encode(config.protocolVersion, config.deploymentVersion));
    }

    function _contractMetadataHash(DeploymentConfig memory config)
        private
        pure
        returns (bytes32)
    {
        return keccak256(bytes(config.contractMetadataURI));
    }

    function _adminHash(DeploymentConfig memory config) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                config.deployer,
                config.adminSafe,
                config.pauseGuardian,
                config.emergencyRecipient,
                config.tdhSigner,
                config.payout
            )
        );
    }

    function _externalDependencyHash(DeploymentConfig memory config)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                config.delegation,
                config.vrfCoordinator,
                config.arrngController,
                config.vrfSubscriptionId
            )
        );
    }

    function _requireConfig(DeploymentConfig memory config) private pure {
        _requireNonEmpty(config.protocolVersion, "Empty protocol version");
        _requireNonEmpty(config.deploymentVersion, "Empty deployment version");
        _requireNonEmpty(config.contractMetadataURI, "Empty contract metadata URI");
        _requireNonZero(config.deployer, "Zero deployer");
        _requireNonZero(config.adminSafe, "Zero admin safe");
        _requireNonZero(config.pauseGuardian, "Zero pause guardian");
        _requireNonZero(config.emergencyRecipient, "Zero emergency recipient");
        _requireNonZero(config.tdhSigner, "Zero signer");
        _requireNonZero(config.payout, "Zero payout");
        _requireNonZero(config.delegation, "Zero delegation");
        _requireNonZero(config.vrfCoordinator, "Zero VRF coordinator");
        _requireNonZero(config.arrngController, "Zero arRNG controller");
        require(config.vrfSubscriptionId != 0, "Zero VRF subscription");
    }

    function _requireNonZero(address value, string memory message) private pure {
        require(value != address(0), message);
    }

    function _requireNonEmpty(string memory value, string memory message) private pure {
        require(bytes(value).length != 0, message);
    }
}
