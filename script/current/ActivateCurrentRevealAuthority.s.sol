// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamRevealActivationPlan.sol";
import "../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";
import "../../smart-contracts/domains/governance/StreamGovernanceActor.sol";

interface CurrentRevealActivationVm {
    function envAddress(string calldata key) external view returns (address);
    function envBytes32(string calldata key) external view returns (bytes32);
    function envBytes(string calldata key) external view returns (bytes memory);
    function startBroadcast(address broadcaster) external;
    function stopBroadcast() external;
}

interface CurrentRevealManagerCore {
    function core() external view returns (address);
}

/// @notice Resume the combined five-call activation returned by new DeployCurrentStack runs.
/// @dev The default testnet roles belong to its controller-owned governance actor.
///      A Safe deployment executes the same saved batch and policy calldata through its Safe.
contract ActivateCurrentRevealAuthority {
    CurrentRevealActivationVm private constant vm =
        CurrentRevealActivationVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (bytes32 actionId) {
        require(block.chainid == 31337 || block.chainid == 11155111, "Anvil or Sepolia only");
        IStreamGovernanceExecutor executor =
            IStreamGovernanceExecutor(vm.envAddress("STREAM_EXECUTOR"));
        IStreamRoleRegistry roles = IStreamRoleRegistry(vm.envAddress("STREAM_ROLE_REGISTRY"));
        IStreamGasParameterHost manager =
            IStreamGasParameterHost(vm.envAddress("STREAM_MINT_MANAGER"));
        StreamEntropyCoordinator entropy =
            StreamEntropyCoordinator(vm.envAddress("STREAM_ENTROPY_COORDINATOR"));
        address actor = vm.envAddress("STREAM_GOVERNANCE_ROOT");
        address administrator = vm.envAddress("STREAM_ARTIST_ADMINISTRATOR");
        actionId = vm.envBytes32("STREAM_ACTIVATION_ACTION_ID");
        StreamArtistActivationPlan.Plan memory plan =
            abi.decode(vm.envBytes("STREAM_ACTIVATION_PLAN"), (StreamArtistActivationPlan.Plan));
        _validateTopology(executor, roles, manager, entropy);
        vm.startBroadcast(vm.envAddress("STREAM_ACTIVATION_SENDER"));
        StreamRevealActivationPlan.execute(
            executor,
            roles,
            manager,
            administrator,
            StreamRevealActivationPlan.Principals(actor, actor, actor),
            actionId,
            plan
        );
        IStreamRevealFeeEscrow.CollectionRevealPolicy memory policy =
            entropy.collectionRevealPolicy(1);
        if (!policy.declared) {
            (address provider,,,,,,) = entropy.collectionEntropyConfig(1);
            StreamGovernanceActor(payable(actor))
                .execute(
                    address(entropy),
                    0,
                    abi.encodeCall(
                        entropy.configureCollectionRevealPolicy,
                        (
                            1,
                            0,
                            keccak256("ROLE_ENTROPY_REVEAL_OWNER"),
                            uint64(100),
                            IStreamEntropyProviderFeeQuote(provider).contextIndependentRequestFee()
                        )
                    )
                );
        }
        policy = entropy.collectionRevealPolicy(1);
        require(
            policy.declared && policy.requestMode == 0
                && policy.revealOwnerRole == keccak256("ROLE_ENTROPY_REVEAL_OWNER")
                && policy.requestSLOBlocks == 100,
            "reveal policy does not match activation"
        );
        _validateTopology(executor, roles, manager, entropy);
        vm.stopBroadcast();
    }

    function _validateTopology(
        IStreamGovernanceExecutor executor,
        IStreamRoleRegistry roles,
        IStreamGasParameterHost manager,
        StreamEntropyCoordinator entropy
    ) private view {
        IStreamCore core = entropy.core();
        require(
            address(core).code.length != 0
                && CurrentRevealManagerCore(address(manager)).core() == address(core)
                && address(entropy.roleRegistry()) == address(roles)
                && entropy.authority() == address(executor)
                && IStreamGovernanceRoleSource(address(executor)).roleRegistry() == address(roles)
                && IStreamRoleRegistryOwnership(address(roles)).owner() == address(executor),
            "activation topology mismatch"
        );
        _requirePointer(core, keccak256("MINT_MANAGER"), address(manager));
        _requirePointer(core, keccak256("ENTROPY_COORDINATOR"), address(entropy));
        (address registry, bytes32 codeHash,,,,,,,,) =
            core.getSatellitePointer(keccak256("MODULE_REGISTRY"));
        require(
            registry.code.length != 0 && registry.codehash == codeHash
                && IStreamMintGovernanceRegistry(registry).governanceExecutor()
                    == address(executor),
            "activation canonical registry mismatch"
        );
    }

    function _requirePointer(IStreamCore core, bytes32 kind, address target) private view {
        (address selected, bytes32 codeHash,,,,,,,,) = core.getSatellitePointer(kind);
        require(
            selected == target && target.code.length != 0 && target.codehash == codeHash,
            "activation selected module mismatch"
        );
    }
}
