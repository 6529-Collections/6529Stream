// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentStackPlan.sol";
import "./StreamGenesisManifestPlan.sol";
import "../../smart-contracts/domains/governance/StreamRoleRegistry.sol";

/// @notice Constructs a sealed governance foundation before products with canonical role pins deploy.
/// @dev The five-leaf bootstrap inventory is historical foundation evidence. Product activation
///      and its full release inventory must be recorded separately through ordinary governance.
library StreamGovernanceGenesisPlan {
    struct Configuration {
        StreamGovernanceExecutor executor;
        StreamRoleRegistry roles;
        StreamCore core;
        StreamModuleRegistry registry;
        StreamSystemManifest manifest;
        address bootstrapAuthority;
        address governanceRoot;
        address[] guardians;
        bytes32 deploymentHash;
        bytes32 manifestModuleHash;
        string moduleURI;
    }

    /// @dev payloadRoot must already contain the exact payload described by update.manifestHash.
    function build(
        Configuration memory c,
        address payloadRoot,
        StreamSystemManifestUpdate memory update
    )
        internal
        view
        returns (SystemManifestBootstrapBinding memory binding, GenesisBatch[] memory batches)
    {
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](2);
        (bytes32 registryHash,,) = c.registry.moduleRegistryManifest();
        records[0] = _record(
            c,
            address(c.registry),
            keccak256("MODULE_REGISTRY"),
            type(IStreamModuleRegistry).interfaceId,
            registryHash
        );
        records[1] = _record(
            c,
            address(c.manifest),
            0x47fd79d5a6e9b1d75dcedf141a46e2e8f6d95d5a5be2b88f197fa98a1436fec6,
            type(IStreamSystemManifest).interfaceId,
            c.manifestModuleHash
        );

        batches = new GenesisBatch[](4);
        batches[0].actionClass = 1;
        (batches[0].calls, batches[0].callDatas) =
            StreamCurrentStackPlan.registrationCalls(c.registry, records);
        bytes32[] memory installTypes = new bytes32[](1);
        installTypes[0] = keccak256("SYSTEM_MANIFEST");
        StreamModuleRegistration[] memory installs = new StreamModuleRegistration[](1);
        installs[0] = records[1];
        batches[1].actionClass = 3;
        (batches[1].calls, batches[1].callDatas) =
            StreamCurrentStackPlan.pointerCalls(c.core, c.registry, installTypes, installs);
        batches[2].actionClass = 2;
        batches[2].calls = new GovernanceCall[](1);
        batches[2].callDatas = new bytes[](1);
        (batches[2].calls[0], batches[2].callDatas[0]) =
            StreamCurrentStackPlan.freezeManifestCall(c.core, c.registry, records[1]);
        batches[3].actionClass = 3;
        batches[3].calls = new GovernanceCall[](2);
        batches[3].callDatas = new bytes[](2);
        batches[3].calls[0].target = address(c.executor);
        batches[3].calls[0].selector = c.executor.sealSystemManifestBootstrap.selector;
        batches[3].calls[1].target = address(c.manifest);
        batches[3].calls[1].selector = c.manifest.publishStreamSystemManifest.selector;

        binding.roleRegistry = address(c.roles);
        binding.governanceRoot = c.governanceRoot;
        binding.governanceRootCodeHash = c.governanceRoot.codehash;
        binding.initialTerminalFreezeVetoGuardians = c.guardians;
        binding.core = address(c.core);
        binding.systemManifestSatellite = address(c.manifest);
        binding.pointerTypes = new bytes32[](2);
        binding.pointerTypes[0] = keccak256("MODULE_REGISTRY");
        binding.pointerTypes[1] = keccak256("SYSTEM_MANIFEST");
        StreamModuleRegistration[] memory pointerRecords = new StreamModuleRegistration[](2);
        pointerRecords[0] = records[0];
        pointerRecords[1] = records[1];
        if (binding.pointerTypes[0] > binding.pointerTypes[1]) {
            (binding.pointerTypes[0], binding.pointerTypes[1]) =
            (binding.pointerTypes[1], binding.pointerTypes[0]);
            (pointerRecords[0], pointerRecords[1]) = (pointerRecords[1], pointerRecords[0]);
        }
        binding.registries = new address[](1);
        binding.registries[0] = address(c.registry);
        (binding.expectedInventoryStateRoot, binding.expectedInventoryLeafCount) =
            StreamCurrentStackPlan.finalInventory(
                address(c.executor),
                c.core,
                c.registry,
                binding.pointerTypes,
                pointerRecords,
                records
            );
        binding.expectedManifestHash = update.manifestHash;
        binding.expectedTriggers = new SystemManifestBootstrapTriggerExpectation[](2);
        binding.expectedTriggers[0] = SystemManifestBootstrapTriggerExpectation(
            address(c.core), c.core.updateSatellitePointer.selector, address(c.core).codehash, 8
        );
        binding.expectedTriggers[1] = SystemManifestBootstrapTriggerExpectation(
            address(c.registry),
            c.registry.setModuleStatus.selector,
            address(c.registry).codehash,
            3
        );
        if (address(c.core) > address(c.registry)) {
            (binding.expectedTriggers[0], binding.expectedTriggers[1]) =
            (binding.expectedTriggers[1], binding.expectedTriggers[0]);
        }
        binding.actionPolicyCandidateProfileHash = c.deploymentHash;
        binding.actionPolicies = _policies(c, batches);
        binding.expectedActionPolicyCatalogHash = StreamGovernanceActionPolicy.expectedCatalogHash(
            address(c.executor), c.deploymentHash, binding.actionPolicies
        );
        (batches[3].calls[0], batches[3].callDatas[0]) = StreamGenesisManifestPlan.sealCall(
            c.executor, c.bootstrapAuthority, binding, payloadRoot
        );
        StreamSystemManifest.ModuleAddresses memory modules;
        modules.streamAdminsOrGovernance = address(c.executor);
        modules.moduleRegistry = address(c.registry);
        (batches[3].calls[1], batches[3].callDatas[1]) =
            StreamGenesisManifestPlan.firstPublicationCall(c.manifest, payloadRoot, update, modules);
    }

    function _record(
        Configuration memory c,
        address module,
        bytes32 moduleType,
        bytes4 interfaceId,
        bytes32 moduleHash
    ) private view returns (StreamModuleRegistration memory) {
        return StreamModuleRegistration(
            module,
            moduleType,
            keccak256("6529stream.governance-foundation.v1"),
            interfaceId,
            500000,
            module.codehash,
            c.deploymentHash,
            moduleHash,
            c.moduleURI
        );
    }

    function _policies(Configuration memory c, GenesisBatch[] memory batches)
        private
        view
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        GovernanceActionPolicyEntry[] memory candidates = new GovernanceActionPolicyEntry[](32);
        uint256 count;
        // Admit exact future-product rows only after their code exists, through a delayed class3 extension.
        candidates[count++] =
            _policy(c, 3, address(c.executor), c.executor.extendGovernanceActionPolicy.selector);
        candidates[count++] =
            _policy(c, 3, address(c.executor), c.executor.rotateGovernanceRoot.selector);
        candidates[count++] =
            _policy(c, 0, address(c.registry), c.registry.setModuleStatus.selector);
        candidates[count++] =
            _policy(c, 1, address(c.registry), c.registry.setModuleStatus.selector);
        candidates[count++] = _policy(c, 1, address(c.roles), c.roles.grantRole.selector);
        candidates[count++] = _policy(c, 1, address(c.roles), c.roles.revokeRole.selector);
        candidates[count++] = _policy(c, 1, address(c.core), c.core.createCollection.selector);
        for (uint8 actionClass; actionClass < 4; ++actionClass) {
            candidates[count++] = _policy(
                c, actionClass, address(c.manifest), c.manifest.publishStreamSystemManifest.selector
            );
        }
        for (uint256 i; i < batches.length; ++i) {
            for (uint256 j; j < batches[i].calls.length; ++j) {
                GovernanceCall memory operation = batches[i].calls[j];
                GovernanceActionPolicyEntry memory next =
                    _policy(c, batches[i].actionClass, operation.target, operation.selector);
                bool exists;
                for (uint256 k; k < count; ++k) {
                    if (_key(candidates[k]) == _key(next)) exists = true;
                }
                if (!exists) candidates[count++] = next;
            }
        }
        rows = new GovernanceActionPolicyEntry[](count);
        for (uint256 i; i < count; ++i) {
            rows[i] = candidates[i];
        }
        for (uint256 i = 1; i < count; ++i) {
            for (uint256 j = i; j > 0 && _key(rows[j - 1]) > _key(rows[j]); --j) {
                (rows[j - 1], rows[j]) = (rows[j], rows[j - 1]);
            }
        }
    }

    function _policy(Configuration memory c, uint8 actionClass, address target, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            actionClass,
            target,
            selector,
            target.codehash,
            keccak256(abi.encode(c.deploymentHash, target)),
            1,
            0,
            0,
            bytes32(0)
        );
    }

    function _key(GovernanceActionPolicyEntry memory entry) private pure returns (bytes32) {
        return keccak256(abi.encode(entry.actionClass, entry.target, entry.selector));
    }
}
