// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentStackDeployment.sol";

interface SepoliaRehearsalVm {
    function envAddress(string calldata) external view returns (address);
    function activeFork() external view returns (uint256);
    function isContext(uint8) external view returns (bool);
    function deal(address, uint256) external;
    function startBroadcast(address) external;
    function stopBroadcast() external;
}

interface SepoliaVRFSubscriptions {
    function createSubscription() external returns (uint256);
    function fundSubscriptionWithNative(uint256) external payable;
    function addConsumer(uint256, address) external;
    function getSubscription(uint256)
        external view returns (uint96, uint96, uint64, address, address[] memory);
}

/// @notice Fork-only deployment rehearsal against the actual Sepolia coordinator.
/// @dev Never broadcast this entry point: it grants simulated ETH and its simulated
///      subscription ID depends on a fork block hash. The live PowerShell helper
///      waits for the real createSubscription receipt before deploying the stack.
contract RehearseSepoliaCurrentStack is StreamCurrentStackDeployment {
    SepoliaRehearsalVm private constant vm =
        SepoliaRehearsalVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (address deployedCore, address deployedProvider, uint256 subId) {
        require(vm.isContext(5), "dry-run context required");
        vm.activeFork();
        require(block.chainid == 11155111, "Sepolia fork required");
        deployer = vm.envAddress("STREAM_DEPLOYER");
        protocol = deployer;
        address selectedArtist = vm.envAddress("STREAM_ARTIST");
        address platform = vm.envAddress("STREAM_PLATFORM_SIGNER");
        localDevelopment = false;
        address upstream = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
        require(upstream.code.length != 0, "actual coordinator code required");
        // This is explicit fork funding, never a claim about the account's live balance.
        vm.deal(deployer, 10 ether);
        vm.startBroadcast(deployer);
        subId = SepoliaVRFSubscriptions(upstream).createSubscription();
        SepoliaVRFSubscriptions(upstream).fundSubscriptionWithNative{value: 0.005 ether}(subId);
        vrfConfig.vrfCoordinator = upstream;
        vrfConfig.subscriptionId = subId;
        vrfConfig.keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
        vrfConfig.requestConfirmations = 3;
        vrfConfig.callbackGasLimit = 1_500_000;
        vrfConfig.maximumCallbackGasLimit = 2_500_000;
        vrfConfig.nativePayment = true;
        _deployCurrentStack(selectedArtist, platform);
        SepoliaVRFSubscriptions(upstream).addConsumer(subId, address(provider));
        vm.stopBroadcast();
        (, uint96 balance,, address subscriptionOwner, address[] memory consumers) =
            SepoliaVRFSubscriptions(upstream).getSubscription(subId);
        require(balance == 0.005 ether && subscriptionOwner == deployer, "subscription readback");
        require(consumers.length == 1 && consumers[0] == address(provider), "consumer readback");
        require(StreamEntropyProviderVRF(address(provider)).subscriptionId() == subId, "adapter subId");
        require(executor.genesisInitialized(), "genesis incomplete");
        return (address(core), address(provider), subId);
    }
}
