// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistActivationPlan.sol";

interface CurrentArtistActivationVm {
    function envAddress(string calldata key) external view returns (address);
    function envBytes32(string calldata key) external view returns (bytes32);
    function envBytes(string calldata key) external view returns (bytes memory);
    function startBroadcast(address broadcaster) external;
    function stopBroadcast() external;
}

/// @notice Resume the one delayed artist-authority batch returned by DeployCurrentStack.
/// @dev Supply the retained action ID and ABI-encoded plan; do not rebuild the plan.
///      This enables artist setup. Artist records, phase consent and Manager handoff
///      are separate subsequent transactions, and are not claimed complete here.
contract ActivateCurrentArtistAuthority {
    CurrentArtistActivationVm private constant vm =
        CurrentArtistActivationVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (bytes32 actionId) {
        require(block.chainid == 31337 || block.chainid == 11155111, "Anvil or Sepolia only");
        IStreamGovernanceExecutor executor =
            IStreamGovernanceExecutor(vm.envAddress("STREAM_EXECUTOR"));
        IStreamRoleRegistry roles = IStreamRoleRegistry(vm.envAddress("STREAM_ROLE_REGISTRY"));
        IStreamGasParameterHost manager =
            IStreamGasParameterHost(vm.envAddress("STREAM_MINT_MANAGER"));
        address administrator = vm.envAddress("STREAM_ARTIST_ADMINISTRATOR");
        actionId = vm.envBytes32("STREAM_ACTIVATION_ACTION_ID");
        StreamArtistActivationPlan.Plan memory plan =
            abi.decode(vm.envBytes("STREAM_ACTIVATION_PLAN"), (StreamArtistActivationPlan.Plan));
        vm.startBroadcast(vm.envAddress("STREAM_ACTIVATION_SENDER"));
        StreamArtistActivationPlan.execute(executor, roles, manager, administrator, actionId, plan);
        vm.stopBroadcast();
    }
}
