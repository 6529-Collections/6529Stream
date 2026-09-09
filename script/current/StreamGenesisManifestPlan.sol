// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/domains/governance/StreamGovernanceExecutor.sol";
import "../../smart-contracts/domains/governance/StreamGovernanceManifest.sol";
import "../../smart-contracts/domains/governance/StreamSystemManifest.sol";
import "../../smart-contracts/libraries/SSTORE2.sol";

/// @notice Deployment-time payload and transition planning shared by tests and
///         broadcast scripts. All address-bound domains name the actual Executor.
library StreamGenesisManifestPlan {
    error InvalidPayloadLength(uint256 length);
    error ManifestReadFailed();

    function writePayload(bytes memory payload)
        internal
        returns (address payloadRoot, bytes32 manifestHash)
    {
        if (payload.length == 0 || payload.length > SSTORE2.MAX_DATA_LENGTH) {
            revert InvalidPayloadLength(payload.length);
        }
        uint32 length = uint32(payload.length);
        bytes32 payloadHash = keccak256(payload);
        StreamGovernanceEvidence.ManifestChunk[] memory chunks =
            new StreamGovernanceEvidence.ManifestChunk[](1);
        chunks[0] =
            StreamGovernanceEvidence.ManifestChunk(SSTORE2.write(payload), length, payloadHash);
        bytes32 format = 0x8844b744a67cdcdb84ea3c6e3d686883da175820b9ff07a19cffa14bf62e6e81;
        bytes32 canonicalization =
            0x886c7c89c308c459ca8a626e0ef36a5ea9f4c7a7b56aaf86c71a2ddf3b4f9044;
        payloadRoot = SSTORE2.write(
            abi.encode(
                bytes4(0x6c9d2530), uint16(1), format, canonicalization, length, uint16(1), chunks
            )
        );
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = keccak256(
            abi.encode(
                bytes32(0x852f4811a2eb32694863d94ba41b545a65ef4c76086a32c35881f0c4e250a7b5),
                uint256(0),
                length,
                payloadHash
            )
        );
        bytes32 listHash = keccak256(
            abi.encode(
                bytes32(0xa93750a5551ac5668c8f24cca85acaf1d5f8334fac9406f845fce1ce35548839),
                length,
                leaves
            )
        );
        manifestHash = keccak256(
            abi.encode(
                bytes32(0xd6ab89b077c61a288c7168cf8f1c9a7a19464b10475735dae37cb46a0c94c40b),
                uint16(1),
                format,
                canonicalization,
                length,
                uint16(1),
                listHash
            )
        );
    }

    function sealCall(
        StreamGovernanceExecutor executor,
        address bootstrapAuthority,
        SystemManifestBootstrapBinding memory binding,
        address payloadRoot
    ) internal view returns (GovernanceCall memory call_, bytes memory data) {
        StreamGovernanceManifest.BootstrapStateView memory state;
        state.bound = true;
        state.roleRegistry = binding.roleRegistry;
        state.roleRegistryCodeHash = binding.roleRegistry.codehash;
        state.governanceRoot = binding.governanceRoot;
        state.governanceRootCodeHash = binding.governanceRootCodeHash;
        state.governanceRootRevision = 1;
        state.initialGuardianCount = binding.initialTerminalFreezeVetoGuardians.length;
        (state.initialGuardianSetHash, state.terminalFreezeVetoMutationChain) =
            _guardianCommitments(address(executor), binding);
        state.terminalFreezeVetoMutationRevision = uint64(state.initialGuardianCount);
        state.core = binding.core;
        state.coreCodeHash = binding.core.codehash;
        state.systemManifestSatellite = binding.systemManifestSatellite;
        state.systemManifestSatelliteCodeHash = binding.systemManifestSatellite.codehash;
        for (uint256 i; i < binding.expectedTriggers.length; ++i) {
            SystemManifestBootstrapTriggerExpectation memory trigger = binding.expectedTriggers[i];
            state.triggerSetHash = keccak256(
                abi.encode(
                    bytes32(0x9927dc0a368efe3d99880bb180d83938664a29ad399291c4544e4cab70c84548),
                    state.triggerSetHash,
                    trigger.triggerTarget,
                    trigger.triggerSelector,
                    trigger.triggerCodeHash,
                    trigger.allowedActionClassMask
                )
            );
        }
        state.triggerCount = binding.expectedTriggers.length;
        state.expectedTriggerSetHash = state.triggerSetHash;
        state.expectedTriggerCount = state.triggerCount;
        state.expectedManifestHash = binding.expectedManifestHash;
        state.expectedInventoryStateRoot = binding.expectedInventoryStateRoot;
        state.expectedInventoryLeafCount = binding.expectedInventoryLeafCount;
        state.inventoryStateRoot = binding.expectedInventoryStateRoot;
        state.inventoryLeafCount = binding.expectedInventoryLeafCount;
        state.bootstrapAuthority = bootstrapAuthority;
        state.actionPolicyCandidateProfileHash = binding.actionPolicyCandidateProfileHash;
        state.actionPolicyCatalogHash = binding.expectedActionPolicyCatalogHash;
        state.actionPolicyEntryCount = binding.actionPolicies.length;
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0xace275f08856e822491961304b01cdc9423d7d16c05518327353df5cd02e33f8),
                uint256(block.chainid),
                address(executor)
            )
        );
        bytes32 oldHash = _bootstrapStateHash(scope, state);
        state.isSealed = true;
        state.sealedPayloadPointer = payloadRoot;
        data = abi.encodeCall(executor.sealSystemManifestBootstrap, ());
        call_ = GovernanceCall(
            address(executor),
            0,
            executor.sealSystemManifestBootstrap.selector,
            keccak256(data),
            scope,
            oldHash,
            _bootstrapStateHash(scope, state)
        );
    }

    function firstPublicationCall(
        StreamSystemManifest manifest,
        address payloadRoot,
        StreamSystemManifestUpdate memory update,
        StreamSystemManifest.ModuleAddresses memory modules
    ) internal view returns (GovernanceCall memory call_, bytes memory data) {
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0xf73b4d7b4d260fce0823707f836fdf29a1767a2a2a9cfbce14ec8c5e49e47841),
                uint256(block.chainid),
                address(manifest)
            )
        );
        StreamSystemManifest.ModuleAddresses memory emptyModules;
        StreamSystemManifest.DiscoveryHashes memory emptyDiscovery;
        bytes32 oldHash = _publicationStateHash(
            scope,
            bytes32(0),
            keccak256(""),
            address(0),
            keccak256(abi.encode(emptyModules)),
            keccak256(abi.encode(emptyDiscovery)),
            0
        );
        bytes32 discoveryHash = keccak256(
            abi.encode(
                update.eventCatalogHash,
                update.compatibilityMatrixHash,
                update.numericIdCatalogHash,
                update.schemaCatalogHash,
                update.canonicalizationCatalogHash,
                update.specBundleHash,
                update.reconstructionClientHash
            )
        );
        bytes32 newHash = _publicationStateHash(
            scope,
            update.manifestHash,
            keccak256(bytes(update.manifestURI)),
            payloadRoot,
            keccak256(abi.encode(modules)),
            discoveryHash,
            1
        );
        data = abi.encodeCall(manifest.publishStreamSystemManifest, (payloadRoot, update));
        call_ = GovernanceCall(
            address(manifest),
            0,
            manifest.publishStreamSystemManifest.selector,
            keccak256(data),
            scope,
            oldHash,
            newHash
        );
    }

    /// @notice Read the canonical flattened ABI as its equivalent structured state.
    function readAggregate(StreamSystemManifest manifest)
        internal
        view
        returns (StreamSystemManifest.AggregateState memory)
    {
        (bool ok, bytes memory result) =
            address(manifest).staticcall(abi.encodeCall(manifest.streamSystemManifest, ()));
        if (!ok) revert ManifestReadFailed();
        // The returned fields are the struct body. A dynamic struct decoder also
        // expects the top-level offset; nested address/hash structs are static.
        return abi.decode(
            bytes.concat(abi.encode(uint256(32)), result), (StreamSystemManifest.AggregateState)
        );
    }

    /// @notice Plan a later publication against the manifest's actual current revision.
    function publicationCall(
        StreamSystemManifest manifest,
        address payloadRoot,
        StreamSystemManifestUpdate memory update,
        StreamSystemManifest.ModuleAddresses memory modules
    ) internal view returns (GovernanceCall memory call_, bytes memory data) {
        (call_, data) = firstPublicationCall(manifest, payloadRoot, update, modules);
        StreamSystemManifest.AggregateState memory current = readAggregate(manifest);
        call_.oldValueHash = _publicationStateHash(
            call_.scopeHash,
            current.manifestHash,
            keccak256(bytes(current.manifestURI)),
            manifest.streamSystemManifestPointer(),
            keccak256(abi.encode(current.modules)),
            keccak256(abi.encode(current.discovery)),
            current.revision
        );
        call_.newValueHash = _publicationStateHash(
            call_.scopeHash,
            update.manifestHash,
            keccak256(bytes(update.manifestURI)),
            payloadRoot,
            keccak256(abi.encode(modules)),
            keccak256(
                abi.encode(
                    update.eventCatalogHash,
                    update.compatibilityMatrixHash,
                    update.numericIdCatalogHash,
                    update.schemaCatalogHash,
                    update.canonicalizationCatalogHash,
                    update.specBundleHash,
                    update.reconstructionClientHash
                )
            ),
            current.revision + 1
        );
    }

    function _guardianCommitments(address executor, SystemManifestBootstrapBinding memory binding)
        private
        view
        returns (bytes32 setHash, bytes32 roleChain)
    {
        address[] memory guardians = binding.initialTerminalFreezeVetoGuardians;
        for (uint256 i; i < guardians.length; ++i) {
            roleChain = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ROLE_MUTATION_V1"),
                    roleChain,
                    uint256(block.chainid),
                    binding.roleRegistry,
                    keccak256("ROLE_TERMINAL_FREEZE_VETO"),
                    guardians[i],
                    true,
                    uint64(i + 1)
                )
            );
        }
        setHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_INITIAL_TERMINAL_GUARDIAN_SET_V1"),
                uint256(block.chainid),
                executor,
                binding.roleRegistry,
                guardians.length,
                roleChain,
                uint64(guardians.length)
            )
        );
        for (uint256 i; i < guardians.length; ++i) {
            setHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_TERMINAL_GUARDIAN_HOLDER_V1"),
                    setHash,
                    i,
                    guardians[i],
                    guardians[i].codehash
                )
            );
        }
    }

    function _bootstrapStateHash(
        bytes32 scope,
        StreamGovernanceManifest.BootstrapStateView memory state
    ) private pure returns (bytes32) {
        return keccak256(
            bytes.concat(
                abi.encode(keccak256("6529STREAM_SYSTEM_MANIFEST_BOOTSTRAP_STATE_V2"), scope),
                abi.encode(state)
            )
        );
    }

    function _publicationStateHash(
        bytes32 scope,
        bytes32 manifestHash,
        bytes32 uriHash,
        address payload,
        bytes32 modulesHash,
        bytes32 discoveryHash,
        uint64 revision
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                bytes32(0x3764ccb415d0aac07f1bddb8d4841ad6d4c2f9b2fe7ce7d221c586bc056aaf60),
                scope,
                manifestHash,
                uriHash,
                payload,
                modulesHash,
                discoveryHash,
                revision
            )
        );
    }
}
