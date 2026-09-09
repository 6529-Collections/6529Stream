// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/core/StreamCore.sol";
import "../../smart-contracts/domains/modules/StreamModuleRegistry.sol";

/// @notice Offchain deployment planner shared by current-stack scripts and tests.
/// @dev Predicts exact transition commitments without mutating contracts or using cheatcodes.
library StreamCurrentStackPlan {
    bytes32 internal constant SYSTEM_MANIFEST = keccak256("SYSTEM_MANIFEST");
    bytes32 internal constant MODULE_REGISTRY = keccak256("MODULE_REGISTRY");
    bytes32 private constant REGISTRATION_SCOPE =
        keccak256("6529STREAM_MODULE_REGISTRATION_SCOPE_V1");
    bytes32 private constant REGISTRATION_STATE =
        keccak256("6529STREAM_MODULE_REGISTRATION_STATE_V1");

    function gasParameters()
        internal
        pure
        returns (StreamCore.GasParameterGenesisConfig[] memory rows)
    {
        rows = new StreamCore.GasParameterGenesisConfig[](4);
        rows[0] = StreamCore.GasParameterGenesisConfig(
            0x9bae92ab1dd0c5535c65125ea4ee7cff3d55fc31fc2555096c2b5eabceb5bcda, 100_000, 25_000, 1
        );
        rows[1] = StreamCore.GasParameterGenesisConfig(
            0x0af6f5a1a5059e398191fa0af185be12fee6d609933826603244c7f247793be7,
            2_910_000,
            1_460_000,
            1
        );
        rows[2] = StreamCore.GasParameterGenesisConfig(
            0x02ad62929eaa837b9d1704745193125454925fd11a6bf273d7bb1faa23272e93,
            1_500_000,
            250_000,
            1
        );
        rows[3] = StreamCore.GasParameterGenesisConfig(
            0x51125071e3dfb233a2711689d4cc377bbda429f1356ebc09a58d763548541e17, 500_000, 120_000, 2
        );
    }

    function registrationCalls(
        StreamModuleRegistry registry,
        StreamModuleRegistration[] memory registrations
    ) internal view returns (GovernanceCall[] memory calls, bytes[] memory data) {
        calls = new GovernanceCall[](registrations.length);
        data = new bytes[](registrations.length);
        (bytes32 chain, uint64 count) = registry.registrationChainHash();
        require(registry.moduleCount() == count, "registry count mismatch");
        for (uint256 i; i < registrations.length; ++i) {
            StreamModuleRegistration memory item = registrations[i];
            bytes32 scope = keccak256(
                abi.encode(REGISTRATION_SCOPE, block.chainid, address(registry), item.module)
            );
            bytes32 nextChain = registrationChain(address(registry), chain, count, item);
            bytes32 oldState = keccak256(
                abi.encode(
                    REGISTRATION_STATE,
                    scope,
                    false,
                    emptyRecordHash(),
                    uint256(count),
                    chain,
                    count,
                    address(0)
                )
            );
            bytes32 nextState = keccak256(
                abi.encode(
                    REGISTRATION_STATE,
                    scope,
                    true,
                    registrationRecordHash(item),
                    uint256(count) + 1,
                    nextChain,
                    count + 1,
                    item.module
                )
            );
            data[i] = abi.encodeCall(registry.registerModule, (item));
            calls[i] = call(address(registry), data[i], scope, oldState, nextState);
            chain = nextChain;
            ++count;
        }
    }

    /// @dev Each registration pairs with one pointer type. Registry is seeded by Core's constructor.
    function pointerCalls(
        StreamCore core,
        StreamModuleRegistry registry,
        bytes32[] memory pointerTypes,
        StreamModuleRegistration[] memory registrations
    ) internal view returns (GovernanceCall[] memory calls, bytes[] memory data) {
        require(pointerTypes.length == registrations.length, "pointer count mismatch");
        calls = new GovernanceCall[](pointerTypes.length);
        data = new bytes[](pointerTypes.length);
        for (uint256 i; i < pointerTypes.length; ++i) {
            StreamCorePointerState memory previous = readPointer(core, pointerTypes[i]);
            StreamCorePointerState memory next =
                pointerState(address(registry), registrations[i], false, previous.revision + 1);
            (bytes32 scope, bytes32 oldState, bytes32 nextState) =
                pointerTransitionHashes(core, pointerTypes[i], previous, next);
            data[i] = abi.encodeCall(
                core.updateSatellitePointer, (pointerTypes[i], registrations[i].module)
            );
            calls[i] = call(address(core), data[i], scope, oldState, nextState);
        }
    }

    function freezeManifestCall(
        StreamCore core,
        StreamModuleRegistry registry,
        StreamModuleRegistration memory manifest
    ) internal view returns (GovernanceCall memory transition, bytes memory data) {
        StreamCorePointerState memory previous = pointerState(address(registry), manifest, false, 1);
        StreamCorePointerState memory next = pointerState(address(registry), manifest, true, 2);
        (bytes32 scope, bytes32 oldState, bytes32 nextState) =
            pointerTransitionHashes(core, SYSTEM_MANIFEST, previous, next);
        data = abi.encodeCall(core.freezeSatellitePointer, (SYSTEM_MANIFEST));
        transition = call(address(core), data, scope, oldState, nextState);
    }

    function createCollectionCall(StreamCore core, uint256 collectionId, uint256 maxSupply)
        internal
        view
        returns (GovernanceCall memory transition, bytes memory data)
    {
        bytes32 scope = keccak256(
            abi.encode(
                0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16,
                block.chainid,
                address(core),
                collectionId
            )
        );
        bytes32 domain = 0x854c83f82b7677e58c61a2482a7a430a8318d765d99a95d3fbce5c84be6cc2b5;
        bytes32 oldState =
            keccak256(abi.encode(domain, scope, false, uint8(0), uint8(0), false, uint256(0)));
        bytes32 nextState =
            keccak256(abi.encode(domain, scope, true, uint8(0), uint8(0), true, maxSupply));
        data = abi.encodeCall(core.createCollection, (uint8(0), true, maxSupply, uint8(0)));
        transition = call(address(core), data, scope, oldState, nextState);
    }

    function pointerState(
        address registry,
        StreamModuleRegistration memory item,
        bool frozen,
        uint64 revision
    ) internal pure returns (StreamCorePointerState memory) {
        return StreamCorePointerState({
            target: item.module,
            codeHash: item.expectedRuntimeCodeHash,
            frozen: frozen,
            moduleType: item.moduleType,
            interfaceId: item.interfaceId,
            registry: registry,
            registryStatus: uint8(ModuleRegistryStatus.ACTIVE),
            moduleManifestHash: item.moduleManifestHash,
            deploymentManifestHash: item.deploymentManifestHash,
            revision: revision
        });
    }

    function readPointer(StreamCore core, bytes32 pointerType)
        internal
        view
        returns (StreamCorePointerState memory)
    {
        (bool ok, bytes memory data) =
            address(core).staticcall(abi.encodeCall(core.getSatellitePointer, (pointerType)));
        require(ok && data.length == 320, "invalid pointer read");
        return abi.decode(data, (StreamCorePointerState));
    }

    function pointerTransitionHashes(
        StreamCore core,
        bytes32 pointerType,
        StreamCorePointerState memory previous,
        StreamCorePointerState memory next
    ) internal view returns (bytes32 scope, bytes32 oldState, bytes32 nextState) {
        scope = keccak256(
            abi.encode(
                0xf4a381d3d4c51db07c19830799ea01c544326118ea1db1fb59d54af5f637bdbb,
                block.chainid,
                address(core),
                pointerType
            )
        );
        oldState = StreamCoreExternalReads.pointerStateHash(scope, previous, previous.revision);
        nextState = StreamCoreExternalReads.pointerStateHash(scope, next, next.revision);
    }

    function call(
        address target,
        bytes memory data,
        bytes32 scope,
        bytes32 oldState,
        bytes32 nextState
    ) internal pure returns (GovernanceCall memory) {
        require(data.length >= 4, "missing selector");
        bytes4 selector;
        assembly ("memory-safe") { selector := mload(add(data, 32)) }
        return GovernanceCall(target, 0, selector, keccak256(data), scope, oldState, nextState);
    }

    function registrationChain(
        address registry,
        bytes32 previous,
        uint64 index,
        StreamModuleRegistration memory item
    ) internal view returns (bytes32) {
        bytes32 recordHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_MODULE_REGISTRATION_RECORD_V1"),
                item.module,
                item.moduleType,
                item.interfaceId,
                item.moduleVersion,
                item.expectedRuntimeCodeHash,
                item.deploymentManifestHash,
                item.moduleManifestHash
            )
        );
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_RECORD_CHAIN_V1"),
                block.chainid,
                registry,
                uint256(0),
                keccak256("MODULE_REGISTRATION"),
                previous,
                recordHash,
                index
            )
        );
    }

    function registrationRecordHash(StreamModuleRegistration memory item)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                uint8(ModuleRegistryStatus.ACTIVE),
                item.moduleType,
                item.moduleVersion,
                item.interfaceId,
                item.moduleGasLimit,
                item.expectedRuntimeCodeHash,
                item.deploymentManifestHash,
                item.moduleManifestHash,
                keccak256(bytes(item.moduleManifestURI)),
                uint64(1)
            )
        );
    }

    function emptyRecordHash() internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                uint8(0),
                bytes32(0),
                bytes32(0),
                bytes4(0),
                uint32(0),
                bytes32(0),
                bytes32(0),
                bytes32(0),
                keccak256(bytes("")),
                uint64(0)
            )
        );
    }

    /// @notice Predicts the sealed inventory for an initially empty canonical registry.
    /// @dev Pointer types and records pair one-to-one; include the constructor-seeded registry.
    function finalInventory(
        address executor,
        StreamCore core,
        StreamModuleRegistry registry,
        bytes32[] memory pointerTypes,
        StreamModuleRegistration[] memory pointerRecords,
        StreamModuleRegistration[] memory allRegistrations
    ) internal view returns (bytes32 root, uint64 count) {
        require(registry.moduleCount() == 0, "genesis registry not empty");
        require(pointerTypes.length == pointerRecords.length, "pointer count mismatch");
        require(pointerTypes.length + 1 + allRegistrations.length <= 80, "inventory too large");
        bytes32 chain;
        for (uint256 i; i < pointerTypes.length; ++i) {
            require(i == 0 || pointerTypes[i - 1] < pointerTypes[i], "unsorted pointers");
            StreamCorePointerState memory pointer = pointerState(
                address(registry),
                pointerRecords[i],
                pointerTypes[i] == SYSTEM_MANIFEST,
                pointerTypes[i] == SYSTEM_MANIFEST ? 2 : 1
            );
            chain = inventoryLeaf(
                chain, count++, 0, address(core), pointerTypes[i], keccak256(abi.encode(pointer))
            );
        }
        bytes32 registrationRoot;
        for (uint256 i; i < allRegistrations.length; ++i) {
            registrationRoot = registrationChain(
                address(registry), registrationRoot, uint64(i), allRegistrations[i]
            );
        }
        (bytes32 manifestHash, string memory uri, uint64 revision) =
            registry.moduleRegistryManifest();
        bytes32 header = keccak256(
            abi.encode(
                address(registry).codehash,
                allRegistrations.length,
                registrationRoot,
                uint64(allRegistrations.length),
                manifestHash,
                keccak256(bytes(uri)),
                revision
            )
        );
        chain = inventoryLeaf(chain, count++, 1, address(registry), bytes32(0), header);
        for (uint256 i; i < allRegistrations.length; ++i) {
            chain = inventoryLeaf(
                chain,
                count++,
                2,
                address(registry),
                bytes32(i),
                moduleInventoryHash(allRegistrations[i])
            );
        }
        root = keccak256(
            abi.encode(
                0xb524bfb9f69adc6c2d0e07003dd39a76b1d6a728dd95dbd495f709428d21b4ec,
                block.chainid,
                executor,
                address(core),
                count,
                chain
            )
        );
    }

    function moduleInventoryHash(StreamModuleRegistration memory item)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                item.module,
                uint8(ModuleRegistryStatus.ACTIVE),
                item.moduleType,
                item.moduleVersion,
                item.interfaceId,
                item.moduleGasLimit,
                item.expectedRuntimeCodeHash,
                item.deploymentManifestHash,
                item.moduleManifestHash,
                keccak256(bytes(item.moduleManifestURI)),
                uint64(1)
            )
        );
    }

    function inventoryLeaf(
        bytes32 prior,
        uint64 index,
        uint8 kind,
        address host,
        bytes32 key,
        bytes32 facts
    ) private pure returns (bytes32) {
        bytes32 leaf = keccak256(
            abi.encode(
                0x389d432187327bb28628b23403c9b3c549d0cf950e480ad6d69b7d9fa7b48b9d,
                kind,
                host,
                key,
                facts
            )
        );
        return keccak256(
            abi.encode(
                0x9efe6891a30e5198982f60b2d916e3275b866addbee37b7d4b875e52d5251e89,
                prior,
                index,
                leaf
            )
        );
    }
}
