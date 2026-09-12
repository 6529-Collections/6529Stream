// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../script/current/StreamDeploymentPlan.sol";
import "../../../smart-contracts/domains/governance/StreamGovernanceActor.sol";

interface ProtectedFoundationVm {
    function isContext(uint8 context) external view returns (bool);
    function startBroadcast(address sender) external;
    function stopBroadcast() external;
    function getNonce(address sender) external view returns (uint64);
}

/// @notice Local script regression for actual foundation planning under Foundry protection.
/// @dev Run without RPC or --broadcast. The fixed sender is a public simulation address.
contract ProtectedFoundation {
    ProtectedFoundationVm private constant vm =
        ProtectedFoundationVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address private constant SENDER = address(0xC6529);

    function run()
        external
        returns (address core, uint64 nonceBeforePlanning, uint64 nonceAfterInitialization)
    {
        require(vm.isContext(5), "local dry-run context required");
        require(block.chainid == 31337, "local simulation chain required");
        uint64 initialNonce = vm.getNonce(SENDER);
        StreamDeploymentPlan planner = new StreamDeploymentPlan();
        require(vm.getNonce(SENDER) == initialNonce, "helper is not a broadcast deployment");
        vm.startBroadcast(SENDER);
        StreamGovernanceGenesisPlan.Configuration memory c;
        c.executor = new StreamGovernanceExecutor(SENDER);
        c.roles = new StreamRoleRegistry(address(c.executor));
        c.registry = new StreamModuleRegistry(
            c.executor, keccak256("protected foundation registry"), "urn:6529stream:test:registry"
        );
        c.governanceRoot = address(new StreamGovernanceActor(SENDER));
        c.guardians = new address[](2);
        c.guardians[0] = address(new StreamGovernanceActor(SENDER));
        c.guardians[1] = address(new StreamGovernanceActor(SENDER));
        if (c.guardians[0] > c.guardians[1]) {
            (c.guardians[0], c.guardians[1]) = (c.guardians[1], c.guardians[0]);
        }
        c.bootstrapAuthority = SENDER;
        c.deploymentHash = keccak256("protected foundation profile");
        c.core = new StreamCore(
            "Protected planning",
            "STREAM",
            address(c.executor),
            StreamCore.GenesisModuleRegistryConfig(
                address(c.registry),
                address(c.registry).codehash,
                keccak256("protected foundation registry"),
                c.deploymentHash
            ),
            StreamCurrentStackPlan.gasParameters()
        );
        c.manifest = new StreamSystemManifest(address(c.core), address(c.executor));
        c.manifestModuleHash = keccak256("protected foundation manifest");
        c.moduleURI = "urn:6529stream:test:foundation";
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
            bytes("{\"purpose\":\"protected local foundation rehearsal\",\"version\":1}")
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash,
            "urn:6529stream:test:manifest",
            keccak256("events"),
            keccak256("compatibility"),
            keccak256("ids"),
            keccak256("schema"),
            keccak256("canonicalization"),
            keccak256("spec"),
            keccak256("client")
        );
        vm.stopBroadcast();
        nonceBeforePlanning = vm.getNonce(SENDER);
        (SystemManifestBootstrapBinding memory binding, GenesisBatch[] memory batches) =
            planner.buildFoundation(c, payload, update);
        require(vm.getNonce(SENDER) == nonceBeforePlanning, "helper read consumes no signer nonce");
        require(
            binding.governanceRoot == c.governanceRoot && binding.core == address(c.core),
            "explicit protocol identities"
        );
        for (uint256 i; i < binding.actionPolicies.length; ++i) {
            require(
                binding.actionPolicies[i].target != address(planner), "helper excluded from plan"
            );
        }
        vm.startBroadcast(SENDER);
        c.executor.commitGenesisPlan(c.executor.hashGenesisPlan(binding, batches));
        c.executor.prepareGenesis(binding, batches);
        c.executor.initializeGenesis(binding, batches);
        vm.stopBroadcast();
        nonceAfterInitialization = vm.getNonce(SENDER);
        require(
            nonceAfterInitialization == nonceBeforePlanning + 3,
            "three intended governance writes only"
        );
        require(c.executor.genesisInitialized(), "actual foundation initialized by resumed signer");
        require(address(c.executor.roleRegistry()) == address(c.roles), "actual roles bound");
        require(
            c.registry.moduleCount() == 2 && c.manifest.streamSystemManifestPointerCount() == 1,
            "actual foundation published"
        );
        return (address(c.core), nonceBeforePlanning, nonceAfterInitialization);
    }
}
